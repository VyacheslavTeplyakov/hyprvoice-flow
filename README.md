# hyprvoice-flow 🎙️⚡

> **Умный голосовой ввод для Hyprland (Wayland)** с поддержкой Push-to-Talk, Hands-free режима, изоляцией аудио и универсальной вставкой в любые приложения (Wayland, XWayland, Electron, Терминалы).

---

## 🚀 Возможности

- **Умный гибридный режим (Smart Hybrid PTT + Toggle):**
  - **Короткие фразы (Push-to-Talk):** зажали кнопку (дольше 400 мс), надиктовали, отпустили — текст сразу вставился.
  - **Длинные мысли (Hands-free Toggle):** кликнули кнопку один раз — запись включилась и не прерывается. Говорите свободно 2–5 минут, не напрягая палец. Кликнули повторно — текст распознался и вставился.
  - **Защита от дребезга:** микроотпускания переключателя мыши больше не обрывают запись на полуслове.
- **Изоляция аудио (Zero Mic Pollution):**
  - Автоматически ставит на паузу медиаплееры (Spotify, браузеры, видео) через `playerctl`.
  - Автоматически глушит динамики через `wpctl` на время записи, чтобы звук из колонок не попадал в микрофон.
  - Мгновенно возвращает громкость и возобновляет воспроизведение после окончания диктовки.
- **Универсальная вставка (Universal Text Injection):**
  - **Терминалы (Kitty, Foot, Alacritty и др.):** использует прямой эмулятор клавиатуры `wtype`.
  - **Нативные Wayland-окна (Chrome, Telegram, Sublime и др.):** скоростная вставка через буфер обмена с мгновенным сохранением Unicode-символов.
  - **XWayland-приложения (OpenAI Codex, ChatGPT, JetBrains, Steam):** использует внутренний Lua-диспетчер Hyprland 0.56+ (`hl.dsp.send_shortcut`) и эмуляцию `Shift+Insert`, гарантируя работу даже при активной **русской раскладке клавиатуры**.
- **Безопасный буфер обмена:**
  - Предыдущее содержимое буфера не затирается, а плавно восстанавливается в фоне через 2 секунды.
  - Если буфер был пуст — надиктованный текст остаётся в буфере (если фокус окна соскочил, текст не потеряется — его можно вставить вручную через `Ctrl+V`).
- **Постобработка через LLM на Groq:**
  - Распознавание через `whisper-large-v3-turbo` (быстро и точно).
  - Постобработка через `openai/gpt-oss-20b`: убирает заикания, слова-паразиты, расставляет знаки препинания и заглавные буквы за ~200 мс.

---

## 📦 Структура репозитория

```text
hyprvoice-flow/
├── bin/
│   └── wtype               # Универсальная обёртка над wtype (Wayland / XWayland / Terminal)
├── scripts/
│   └── hyprvoice_talk.sh   # Контроллер записи (PTT + Toggle + аудио)
├── config/
│   ├── config.toml.example # Шаблон конфигурации hyprvoice (БЕЗ ключей)
│   ├── hyprland.conf.example # Пример биндов для Hyprland
│   └── chatgpt-flags.conf  # Флаги нативного Wayland для Electron / Codex
├── systemd/
│   └── hyprvoice.service   # Юнит systemd с поддержкой правильного PATH
├── install.sh              # Скрипт автоматической установки
├── LICENSE                 # MIT License
└── README.md
```

---

## 🛠️ Зависимости

Для работы требуются следующие системные утилиты:
- [hyprvoice](https://github.com/leonardotrapani/hyprvoice) — демон голосового ввода (`hyprvoice-bin` в AUR)
- `hyprland` (0.50+)
- `wtype` — эмулятор ввода Wayland
- `wl-clipboard` (`wl-copy`, `wl-paste`)
- `playerctl` — управление медиа
- `wireplumber` (`wpctl`) — управление звуком
- `jq` — парсинг JSON

На Arch Linux / CachyOS:
```bash
sudo pacman -S wtype wl-clipboard playerctl wireplumber jq
paru -S hyprvoice-bin
```

---

## ⚡ Установка

1. Клонируйте репозиторий:
   ```bash
   git clone <URL_РЕПОЗИТОРИЯ> hyprvoice-flow
   cd hyprvoice-flow
   ```

2. Запустите инсталлятор:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   > Инсталлятор проверит зависимости, установит скрипты в `~/.local/bin/` и `~/.config/hypr/scripts/`, настроит службу `systemd` и предложит ввести ключ Groq API (если конфиг ещё не создан). Существующие конфиги и ключи инсталлятор **не перезаписывает**.

3. Добавьте бинды в ваш `~/.config/hypr/hyprland.conf`:
   ```ini
   # Голосовой ввод: Push-to-Talk (удержание) и Hands-free (клик) на боковой кнопке мыши
   bind  = , mouse:275, exec, ~/.config/hypr/scripts/hyprvoice_talk.sh start
   bindr = , mouse:275, exec, ~/.config/hypr/scripts/hyprvoice_talk.sh stop
   ```
   *(Или на клавиатуру, например `SUPER, Space`).*

4. Перезагрузите конфигурацию Hyprland:
   ```bash
   hyprctl reload
   ```

---

## ⚙️ Настройка API ключа

Получите бесплатный ключ API на [console.groq.com](https://console.groq.com).

В файле `~/.config/hyprvoice/config.toml`:
```toml
[providers.groq]
  api_key = "gsk_ВАШ_КЛЮЧ"

[transcription]
  provider = "groq-transcription"
  model = "whisper-large-v3-turbo"
  language = "ru"

[llm]
  enabled = true
  provider = "groq"
  model = "openai/gpt-oss-20b"
```

После редактирования перезапустите службу:
```bash
systemctl --user restart hyprvoice.service
```

---

## 🔒 Безопасность

Файл конфигурации `config.toml`, переменные окружения `.env` и секретные ключи добавлены в `.gitignore` и **никогда не попадут в репозиторий**.

---

## 📄 Лицензия

MIT License.
