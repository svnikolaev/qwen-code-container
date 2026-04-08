# Qwen Code в Docker — безопасный запуск с защитой секретов

## Быстрый старт

1. **Клонируйте проект** в любое место:

   ```bash
   git clone https://github.com/YOUR_USERNAME/qwen-code-container.git ~/dev/qwen-code-container
   cd ~/dev/qwen-code-container
   ```

2. **Установите глобальную команду `qcc`** (один раз):

   ```bash
   make install
   ```

   Добавьте `~/.local/bin` в PATH:

   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Настройте авторизацию** (один раз):

   ```bash
   make setup
   ```

4. **Перейдите в любой проект** и запустите:

   ```bash
   cd ~/my-project
   qcc
   ```

## Как работает защита

- Файл **`.qwenignore`** в корне проекта — автоматическое перекрытие файлов без вопросов.
- Все монтирования описаны непосредственно в скрипте `bin/qwen-run` (без docker compose).
- Скрипт `bin/qwen-run` — тонкая обёртка (~120 строк), которая вычисляет переменные и запускает `docker run` с правильными монтированиями.

### Глобальная конфигурация

Все общие данные хранятся в **`~/.config/qwen-code-container/`** (XDG Base Dir):

| Путь                | Назначение                           |
| ------------------- | ------------------------------------ |
| `projects/<hash>/.qwen/` | Авторизация и настройки Qwen Code (на проект) |
| `npm/`              | Кэш npm (не загрязняет проект)       |
| `config/`           | Общие конфиги (не загрязняют проект) |
| `skills/`           | Глобальные скиллы для AI-агентов     |
| `model`             | Версия модели по умолчанию           |

Проект остаётся чистым — никаких `.npm/`, `.config/`, `.qwen/` в рабочей директории.

### Системный промпт `AGENTS.md`

Если в корне проекта лежит **`AGENTS.md`**, он передаётся AI как набор инструкций:
безопасность, стиль кода, правила git commit.

### Формат `.qwenignore`

```qwenignore
# Секреты
.env
*.key
secrets/
credentials.json
```

Скопируйте `.qwenignore.example` в `.qwenignore` и отредактируйте под свой проект.

## Команды

| Команда          | Действие                                 |
| ---------------- | ---------------------------------------- |
| `qcc`            | запуск Qwen Code в контейнере            |
| `make shell`     | bash в контейнере (от текущего пользователя) |
| `make shell-root`| подключиться к запущенному qcc (root bash) |
| `make setup`     | создать config.json (OAuth) + шаблоны    |
| `make clean`     | удалить `~/.config/qwen-code-container`  |
| `make install`   | symlink `qcc` → `~/.local/bin/qcc`       |
| `make uninstall` | удалить symlink                          |
| `make check-deps`| проверить зависимости (docker, jq)       |
| `make model`     | показать текущую модель                  |
| `make set-model` | установить модель (`MODEL=qwen3.6-plus`) |

## Модель

qwen-code — это **клиент**. Модель работает на сервере провайдера (Google, OpenRouter и т.д.).
Версия модели **не зависит** от Docker-образа.

### Как узнать текущую модель

```bash
qcc --model         # покажет заданную модель
make model          # то же через make
```

### Как установить модель

```bash
make set-model MODEL=qwen3.6-plus
qcc --model         # проверить
```

Модель сохраняется в `~/.config/qwen-code-container/model` и передаётся как `--model <версия>` при каждом запуске.

### Как убедиться, что используется последняя версия

1. Проверить актуальную версию на [qwen.ai](https://qwen.ai) или в [блоге Qwen](https://qwenlm.github.io/)
2. Установить: `make set-model MODEL=qwen3.6-plus`
3. При выходе новой версии — обновить: `make set-model MODEL=qwen3.7-plus`

## Требования

- Docker (или Podman)
- `jq` — `sudo apt install jq` / `brew install jq`

## Устранение неполадок

**Авторизация не сохраняется** — проверьте `~/.config/qwen-code-container/projects/<hash>/.qwen/`.

**В проекте появились `.npm/` или `.config/`** — удалите их, теперь они монтируются из глобального конфига.

**Миграция** — при первом запуске после обновления `~/.qwen-docker` автоматически перенесётся в `~/.config/qwen-code-container`.

**Проблемы с запуском** — убедитесь, что вы в корне проекта (где `Makefile` и `bin/qwen-run`).

## Структура проекта

```
.
├── bin/
│   └── qwen-run              # Тонкая обёртка над docker run (~120 строк)
├── container/
│   └── entrypoint.sh         # Entry-point контейнера: git config + skills
├── config-templates/
│   ├── agent/                # Глобальные конфиги AI-агента
│   ├── qwen/                 # Шаблоны конфитов Qwen
│   └── skills/               # Глобальные скиллы
├── docs/
│   └── ТЕХНИЧЕСКОЕ_ЗАДАНИЕ.md  # Полное ТЗ и описание реализации
├── Makefile                  # Команды управления
├── .env.example              # Пример переменных окружения
└── .qwenignore.example       # Пример файла перекрытия
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
