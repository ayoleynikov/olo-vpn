# Olo

**Открытый VPN‑клиент для iPhone и Mac** с крупным понятным интерфейсом.

Идея как у Shadowrocket: вставил ссылку или подписку → сервер в списке → большая кнопка подключения. Код Shadowrocket не используется.

Туннель: Apple **Network Extension** + движок **[sing-box / Libbox](https://github.com/SagerNet/sing-box)** (GPL‑3.0).

<p align="center">
  <img src="OloVPN/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="128" alt="Olo icon" />
</p>

## Возможности

| | |
|---|---|
| **Серверы** | Ссылка `ss://` · `vless://` · `trojan://` · `hy2://`, https‑подписки (Shadowrocket), QR, ручная форма с авто‑определением протокола |
| **Маршрут** | Умный режим: местные сайты региона мимо VPN или через него; либо весь трафик в туннель |
| **Защита IP** | Kill switch, DNS через VPN, блок IPv6, проверка «мой IP / страна», утечки |
| **Монитор** | Лог подключений, текущий публичный IP, скорость, куда уходит трафик, графики |
| **Удобства** | Пинг серверов, авто‑обновление подписок |

## Стек

- SwiftUI (iPhone + Mac)
- `PacketTunnel` Network Extension
- Libbox (sing-box) — скачивается скриптом, не лежит в git (~350 MB)
- XcodeGen → `project.yml`

## Быстрый старт

```bash
# 1. Libbox
./scripts/fetch_libbox.sh

# 2. Xcode‑проект
brew install xcodegen   # если ещё нет
xcodegen generate
open OloVPN.xcodeproj
```

Схемы в Xcode:

- **OloVPN** — Mac  
- **OloVPN-iOS** — iPhone  

Нужен [Apple Developer](https://developer.apple.com) ($99/год): capability **Network Extensions** + App Group `group.app.olo.vpn` для:

- `app.olo.vpn`
- `app.olo.vpn.PacketTunnel`

На симуляторе туннель не поднимается — UI и демо‑монитор работают. Реальный VPN — на устройстве / Mac с подписью.

## Структура

```
OloVPN/          UI и сервисы приложения
PacketTunnel/    Network Extension (Libbox)
Shared/          общие константы (App Group)
scripts/         fetch_libbox.sh
project.yml      XcodeGen
```

## Сборка без подписи (проверка)

```bash
xcodebuild -scheme OloVPN -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme OloVPN-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro' CODE_SIGNING_ALLOWED=NO build
```

## Лицензия и магазин

Проект: **[GPL‑3.0-or-later](LICENSE)** — открытый исходный код, совместимо с sing-box.

App Store и GPL стыкуются плохо: для публикации в Store обычно нужен другой движок или иное право. Сейчас логичный путь — GitHub + TestFlight / прямая установка по Developer ID.

## Статус

Активная разработка. UI и импорт конфигов готовы; туннель на Libbox подключён в проекте — для продакшена нужна ваша Apple‑подпись и проверка на железе.

## Благодарности

- [sing-box](https://github.com/SagerNet/sing-box) — ядро прокси  
- Открытые клиенты на Libbox — паттерны Packet Tunnel  
