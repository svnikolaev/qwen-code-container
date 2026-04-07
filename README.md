# Qwen Code в Docker — безопасный запуск с защитой секретов

## Быстрый старт

1. **Клонируйте проект** в любое место:

   ```bash
   git clone https://github.com/ваш-репозиторий/qwen-code-docker.git ~/dev/qwen-code-docker
   cd ~/dev/qwen-code-docker
   ```

2. **Установите глобальную команду `qwen`** (один раз):

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
   qwen
   ```

## Как работает защита

- При запуске `qwen` сканирует проект на наличие секретов (`.env`, `*.key`, `secrets/` и т.д.).
- Файл **`.qwenignore`** в корне проекта — автоматическое перекрытие без вопросов.
- Для остальных найденных файлов **спрашивает** — скрыть или нет.
- Выбор запоминается в `~/.config/qwen-code-docker/blocked-paths.json`.
- `qwen --refresh` — переспросить, `qwen --show-blocked` — показать перекрытые.

### Глобальная конфигурация

Все общие данные хранятся в **`~/.config/qwen-code-docker/`** (XDG Base Dir):

| Путь                 | Назначение                            |
| -------------------- | ------------------------------------- |
| `qwen/`              | Авторизация и настройки Qwen Code     |
| `npm/`               | Кэш npm (не загрязняет проект)        |
| `config/`            | Общие конфиги (не загрязняют проект)  |
| `skills/`            | Глобальные скиллы для AI-агентов      |
| `blocked-paths.json` | Выбор перекрытия секретов по проектам |
| `cmd`                | Кэш команды внутри контейнера         |

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

| Команда               | Действие                                 |
| --------------------- | ---------------------------------------- |
| `qwen`                | запуск с защитой                         |
| `qwen --refresh`      | переспросить о перекрытии                |
| `qwen --show-blocked` | показать перекрытые файлы                |
| `qwen --model`        | показать текущую модель                  |
| `make shell`          | bash в контейнере (без защиты)           |
| `make setup`          | создать config.json (OAuth)              |
| `make clean`          | удалить `~/.config/qwen-code-docker`     |
| `make install`        | symlink `qwen` → `~/.local/bin/qwen`     |
| `make uninstall`      | удалить symlink                          |
| `make check-deps`     | проверить и установить jq                |
| `make model`          | показать текущую модель                  |
| `make set-model`      | установить модель (`MODEL=qwen3.6-plus`) |

## Модель

qwen-code — это **клиент**. Модель работает на сервере провайдера (Google, OpenRouter и т.д.).
Версия модели **не зависит** от Docker-образа.

### Как узнать текущую модель

```bash
qwen --model        # покажет заданную модель
make model          # то же через make
```

### Как установить модель

```bash
make set-model MODEL=qwen3.6-plus
qwen --model        # проверить
```

Модель сохраняется в `~/.config/qwen-code-docker/model` и передаётся как `--model <версия>` при каждом запуске.

### Как убедиться, что используется последняя версия

1. Проверить актуальную версию на [qwen.ai](https://qwen.ai) или в [блоге Qwen](https://qwenlm.github.io/)
2. Установить: `make set-model MODEL=qwen3.6-plus`
3. При выходе новой версии — обновить: `make set-model MODEL=qwen3.7-plus`

## Требования

- Docker (или Podman)
- `jq` — `sudo apt install jq` / `brew install jq`

## Устранение неполадок

**Авторизация не сохраняется** — проверьте `~/.config/qwen-code-docker/qwen/`.

**В проекте появились `.npm/` или `.config/`** — удалите их, теперь они монтируются из глобального конфига.

**Миграция** — при первом запуске после обновления `~/.qwen-docker` автоматически перенесётся в `~/.config/qwen-code-docker`.
