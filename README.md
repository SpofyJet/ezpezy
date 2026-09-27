# 🛡 Selfsteal Caddy Installer

> Поднимает **fakesite на своём домене** (Caddy в Docker) для использования как `dest` в XRay Reality.
> Один скрипт, один домен, валидный TLS-сертификат от Let's Encrypt.

[![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?logo=gnubash&logoColor=white)]()
[![Docker](https://img.shields.io/badge/Docker-required-2496ED?logo=docker&logoColor=white)]()
[![Caddy](https://img.shields.io/badge/Caddy-2.x-1F88C0?logo=caddy&logoColor=white)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## 🎯 Что делает

- Ставит Docker и Docker Compose (если их нет)
- Поднимает **Caddy в контейнере** (`selfsteal-caddy`)
- Генерирует Caddyfile под твой домен
- Автоматически выпускает **сертификат Let's Encrypt** (HTTP-01)
- Кладёт HTML-fakesite (6 шаблонов) в `/opt/selfsteal/html/`
- **HTTPS fakesite слушает только локально** — `127.0.0.1:8443` или unix-сокет `/dev/shm/selfsteal.sock`;
  наружу открыт лишь `:80` (выпуск сертификата и редирект браузеров). Порт 443 остаётся Xray.
- **Без HTTP/3 (UDP)**: REALITY ходит к dest только по TCP, а UDP-сокет Caddy на 443 конфликтовал бы с Hysteria2

### Почему selfsteal — самый быстрый dest

Нода ждёт ответа dest при **каждом** подключении клиента (REALITY открывает соединение к dest и ждёт
TLS-рукопожатия). Замер на тестовой ноде (VLESS+REALITY, время до первого байта, новое соединение на
каждый запрос, медианы):

| dest | время до первого байта |
|---|---|
| `www.cloudflare.com:443` (~4 мс от ноды) | 38–41 мс |
| selfsteal `127.0.0.1:8443` | 17–20 мс |
| selfsteal unix-сокет | 15–17 мс (в пределах шума — как 127.0.0.1) |

Далёкий dest добавляет два своих RTT к каждому соединению: +150 мс до dest дали +300 мс до первого байта.

После установки подставь в XRay Reality инбаунд:

```json
"dest": "127.0.0.1:8443",
"serverNames": ["cdn.example.com"]
```

---

## 🚀 Установка

### 1. Настрой DNS

Добавь A-запись в DNS-панели регистратора:

```
cdn.example.com   A   <IP сервера>   TTL 300
```

Проверь:

```bash
dig +short cdn.example.com
```

Должен вернуть IP сервера.

### 2. Запусти скрипт

```bash
bash <(curl -Ls https://raw.githubusercontent.com/SpofyJet/ezpezy/main/install.sh)
```

Скрипт спросит:
- Домен (например `cdn.example.com`)
- Как Xray обращается к fakesite: `127.0.0.1:порт` (по умолчанию 8443) или unix-сокет
- Шаблон сайта

Порт **80 должен быть открыт снаружи** (UFW / фаервол провайдера) — через него Let's Encrypt выдаёт сертификат.

Без вопросов (автоматизация):

```bash
SELFSTEAL_DOMAIN=cdn.example.com SELFSTEAL_MODE=tcp SELFSTEAL_PORT=8443 SELFSTEAL_TEMPLATE=1 \
  bash <(curl -Ls https://raw.githubusercontent.com/SpofyJet/ezpezy/main/install.sh)
```

Переустановка (`SELFSTEAL_REINSTALL=1` — без вопроса) сохраняет `data/`: сертификат не выпускается
заново (у Let's Encrypt лимит — 5 одинаковых сертификатов в неделю).

---

## 🧪 Проверка

```bash
selfsteal test          # запрос к fakesite локально с SNI домена: ожидается HTTP/2 200

# Сертификат валидный?
echo | openssl s_client -connect 127.0.0.1:8443 -servername cdn.example.com 2>/dev/null \
  | openssl x509 -noout -subject -dates
# для unix-сокета: openssl s_client -unix /dev/shm/selfsteal.sock -servername cdn.example.com
```

Ожидаемый вывод:

```
subject=CN = cdn.example.com
notBefore=...
notAfter=...
```

Снаружи `https://cdn.example.com` открывает тот же fakesite: браузер приходит на 443 к Xray, и REALITY
отдаёт чужие подключения в dest.

---

## ⚙️ Управление

```bash
cd /opt/selfsteal

# Логи
docker logs -f selfsteal-caddy

# Рестарт
docker compose restart

# Стоп
docker compose down

# Старт
docker compose up -d
```

---

## 📁 Структура

```
/opt/selfsteal/
├── Caddyfile             # конфиг Caddy
├── docker-compose.yml    # docker-compose с network_mode: host
├── .env                  # домен и email
├── html/                 # fakesite (можешь заменить своим контентом)
├── data/                 # серты Caddy (Let's Encrypt account + cert)
└── logs/                 # access-логи
```

Чтобы заменить fakesite — просто положи свой `index.html` (и любые ассеты) в `/opt/selfsteal/html/`.

---

## 🔧 XRay Reality

После установки в инбаунде XRay укажи (unix-сокет — `"dest": "/dev/shm/selfsteal.sock"`):

```json
"streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
        "dest": "127.0.0.1:8443",
        "show": false,
        "xver": 0,
        "shortIds": ["..."],
        "privateKey": "...",
        "serverNames": ["cdn.example.com"]
    }
}
```

В клиенте/панели Remnawave используй тот же домен в поле SNI.

Для unix-сокета контейнеру remnanode нужен доступ к `/dev/shm` — в его `docker-compose.yml`:

```yaml
    volumes:
      - /dev/shm:/dev/shm
```

и `docker compose up -d`. Быстрее, чем `127.0.0.1:8443`, это не делает (замер одинаковый) — плюс только в
том, что у fakesite нет TCP-порта.

---

## ❓ Troubleshooting

**Серт не выпускается, в логах `challenge failed`**
Проверь что A-запись домена указывает именно на этот сервер и что порт 80 не заблокирован файрволом провайдера.

**Порт занят**
Скрипт предложит остановить `nginx`/`caddy`/`apache2`. Порт, занятый Xray (`xray`, `rw-core`), он не
отбирает — выбери для fakesite другой локальный порт. `ss -tlnp | grep -E ':(80|8443) '` покажет процесс.

**Хочу поменять домен**
Отредактируй `/opt/selfsteal/Caddyfile`, замени старый домен на новый, перезапусти: `docker compose down && docker compose up -d`. Серт выпустится заново автоматически.

---

## 📜 Лицензия

MIT
