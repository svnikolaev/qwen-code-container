# Описание реализации: Qwen Code Container

**Версия документа:** 4.0
**Версия проекта:** 0.2.1

---

## ЧАСТЬ II. ОПИСАНИЕ РЕАЛИЗАЦИИ

---

### 10. Реализованная архитектура

#### 10.1. Файловая структура проекта

```text
qwen-code-container/
├── bin/
│   └── qwen-run              # Главный launcher-скрипт (bash, ~330 строк)
├── container/
│   └── entrypoint.sh         # Entry-point контейнера (bash, ~12 строк)
├── config-templates/
│   ├── agent/
│   │   └── AGENTS.md         # Шаблон промпта для AI-агента
│   ├── qwen/
│   │   ├── output-language.md # Промпт: отвечать на английском
│   │   └── .gitignore        # Git-игнор для шаблонов Qwen
│   └── skills/
│       ├── file-consistency-checker.md
│       ├── git-commit.md
│       ├── five-whys.md
│       └── session-state-saver.md
├── docs/
│   ├── specification.md       # Техническое задание (абстрактное)
│   └── implementation.md      # Описание реализации (этот файл)
├── Makefile                  # ~280 строк, 15+ целей
├── VERSION                   # Текущая версия проекта (0.2.0)
├── .env.example              # Пример переменных окружения
├── .qwenignore.example       # Пример .qwenignore
├── LICENSE                   # MIT License
└── README.md                 # Пользовательская документация
```

> **AGENTS.md** не хранится в git (добавлен в `.gitignore`).
> Шаблон — `config-templates/agent/AGENTS.md`.

#### 10.2. Реализация .qwenignore

**Файл:** `bin/qwen-run`, блок «Обработка .qwenignore»

**Алгоритм:**

1. Если существует `$PROJECT_DIR/.qwenignore` — читаем построчно
2. Удаляем комментарии (всё после `#`) и пустые строки
3. Для каждого паттерна ищем файлы через `find -maxdepth 2`
4. Каждый найденный файл добавляется в `OVERLAY_VOLUMES` как `-v /workspace/<относительный_путь>`
5. Docker монтирует пустой anonymous volume поверх файла, делая его недоступным внутри контейнера

#### 10.3. Реализация запуска контейнера

**Файл:** `bin/qwen-run`

**Именование контейнера:**

```bash
PROJECT_HASH=$(echo -n "$PROJECT_DIR" | md5sum | cut -d' ' -f1)
CONTAINER_NAME="qcc-$(echo "$PROJECT_HASH" | head -c 8)"
```

**Определение runtime:**

```bash
if docker --version 2>/dev/null | grep -qi podman; then
    RUNTIME="podman"
    USER_OPTS="--userns=keep-id --group-add keep-groups"
else
    RUNTIME="docker"
    USER_OPTS="--user $(id -u):$(id -g) --group-add keep-groups"
fi
```

**Поиск свободного порта:**

```bash
find_free_port() {
    local port=$1
    local max_attempts=20
    local i=0
    while [ $i -lt $max_attempts ]; do
        if ! $CONTAINER_CMD ps --format '{{.Ports}}' 2>/dev/null | grep -q ":${port}->"; then
            echo "$port"
            return
        fi
        port=$((port + 1))
        i=$((i + 1))
    done
    echo "$1"
}
```

**Опции пользователя:**

| Runtime | Опции                                              |
| ------- | -------------------------------------------------- |
| Docker  | `--user $(id -u):$(id -g) --group-add keep-groups` |
| Podman  | `--userns=keep-id --group-add keep-groups`         |

**Полная команда docker:**

```bash
docker run --rm -it \
    --name "$CONTAINER_NAME" \
    $USER_OPTS \
    --security-opt label=disable --security-opt no-new-privileges:true \
    --label "qcc.project_hash=$PROJECT_HASH" \
    "${VOLUMES[@]}" \
    "${TMPFS[@]}" \
    "${GIT_ENVS[@]}" \
    -e QWEN_ALLOW_RUN_IN_HOME=1 \
    -w /workspace \
    --entrypoint /usr/local/bin/git-entrypoint.sh \
    -p "${RESOLVED_HOST_PORT}:${CONTAINER_PORT}" \
    "$QWEN_IMAGE" \
    qwen "${MODEL_ARGS[@]}"
```

Команда `qwen` внутри контейнера захардкожена (образ Qwen Code содержит эту команду).

#### 10.4. Проверка существующего контейнера

При запуске `qcc` проверяется, запущен ли контейнер для текущего проекта:

- **Если запущен** — предлагается подключиться к сессии или перезапустить
- **Флаг `--attach`** — сразу подключиться к сессии (`docker attach`)
- **Флаг `--new`** — остановить старый и запустить новый

#### 10.5. Entry-point контейнера

**Файл:** `container/entrypoint.sh`

```bash
#!/bin/bash
# Применяем git config с хоста
[ -n "$GIT_CONFIG_NAME" ] && git config --global user.name "$GIT_CONFIG_NAME"
[ -n "$GIT_CONFIG_EMAIL" ] && git config --global user.email "$GIT_CONFIG_EMAIL"

exec "$@"
```

Entry-point минимален — только настройка git перед запуском основной команды.
Скиллы больше не требуют symlink, так как монтируются напрямую в `/workspace/.qwen/skills`.

#### 10.6. Глобальная конфигурация — реализация

**Базовый путь:** `${XDG_CONFIG_HOME:-$HOME/.config}/${CONFIG_NAME}`

**Инициализация при `make install`:**

1. Создаются директории: `npm/`, `config/`, `skills/`
2. Скиллы из `config-templates/skills/*.md` копируются в глобальные `skills/` (с проверкой на существование)
3. `AGENTS.md` копируется в глобальные конфиги (с проверкой)
4. Создаётся symlink: `~/.local/bin/qcc` → `bin/qwen-run`

**Проектные конфиги:** создаются автоматически при запуске:

```bash
PROJECT_HASH=$(echo -n "$PROJECT_DIR" | md5sum | cut -d' ' -f1)
PROJECT_QWEN_DIR="$GLOBAL_CONFIG_DIR/projects/$PROJECT_HASH/.qwen"
mkdir -p "$PROJECT_QWEN_DIR"
```

**Копирование шаблонов:** при каждом запуске из `config-templates/qwen/` в `PROJECT_QWEN_DIR` (кроме `.gitignore`, только если файла ещё нет).

#### 10.7. Makefile — все цели

| Цель           | Описание                                                    |
| -------------- | ----------------------------------------------------------- |
| `help`         | Список всех целей и переменных + версия                     |
| `version`      | Показать версию проекта                                     |
| `run`          | Запуск через `bin/qwen-run`                                 |
| `shell`        | Bash в контейнере текущего проекта (по хэшу)                |
| `setup`        | Создать `config.json` с OAuth + скопировать шаблоны         |
| `clean`        | Удалить глобальную конфигурацию                             |
| `install`      | Установить команду `qcc` + инициализировать конфиги         |
| `uninstall`    | Удалить symlink `qcc`                                       |
| `check-deps`   | Проверить Docker, установить jq при необходимости           |
| `pull-image`   | `docker pull` образа                                        |
| `remove-image` | `docker rmi` образа                                         |
| `test-image`   | Проверка работоспособности образа (зависит от `pull-image`) |
| `model`        | Показать текущую модель                                     |
| `set-model`    | Установить модель (`MODEL=...`)                             |
| `config-update`| Обновить конфиги из шаблонов                                |
| `stop`         | Остановить все контейнеры qcc-*                             |

#### 10.8. Переменные окружения — реализация

| Переменная                     | Где используется       | Примечание               |
| ------------------------------ | ---------------------- | ------------------------ |
| `QWEN_IMAGE`                   | `Makefile`, `qwen-run` | Образ по умолчанию       |
| `QWEN_CONFIG_NAME`             | `Makefile`, `qwen-run` | Имя папки конфигов        |
| `QWEN_MODEL`                   | `Makefile`, `qwen-run` | Модель из Makefile       |
| `QWEN_MODEL_EXPLICIT`          | `Makefile`, `qwen-run` | Флаг явной установки     |
| `HOST_PORT` / `CONTAINER_PORT` | `qwen-run`             | Проброс порта `-p`       |
| `GIT_CONFIG_NAME`              | `qwen-run`             | Передаётся в контейнер   |
| `GIT_CONFIG_EMAIL`             | `qwen-run`             | Передаётся в контейнер   |

#### 10.9. Безопасность — реализация

| Механизм                  | Реализация                                                                |
| ------------------------- | ------------------------------------------------------------------------- |
| Без привилегий            | `--security-opt no-new-privileges:true`                                   |
| Пользователь              | `--user $(id -u):$(id -g)` (Docker) / `--userns=keep-id` (Podman)         |
| SELinux                   | `--security-opt label=disable`                                            |
| Временные директории      | `--tmpfs /workspace/.npm:mode=755`, `--tmpfs /workspace/.config:mode=755` |
| `.qwen` в проекте         | Bind-mount в `PROJECT_QWEN_DIR` (не tmpfs, не создаётся в проекте)        |
| Read-only монтирование    | `entrypoint.sh:ro`                                                        |
| Rw монтирование           | `skills`, `AGENTS.md`, `.qwen`                                            |
| Метка проекта             | `--label "qcc.project_hash=$PROJECT_HASH"`                                |
| Подавление предупреждений | `-e QWEN_ALLOW_RUN_IN_HOME=1`                                             |

#### 10.9. Скиллы — реализация

Скиллы хранятся в `config-templates/skills/` и копируются при `make install` в
`~/.config/qwen-code-container/skills/`, а оттуда — в проектную директорию
`projects/<hash>/skills/`. В контейнере монтируются как `/workspace/.qwen/skills` (rw).

**File Consistency Checker** (`config-templates/skills/file-consistency-checker.md`):

- Проверяет наличие ключевых файлов проекта
- Запускает `bash -n` для проверки синтаксиса скриптов
- Проверяет исполняемость `bin/qwen-run` и `container/entrypoint.sh`
- Сравнивает шаблоны `config-templates/` с ожидаемым состоянием
- Выводит итоговый отчёт с ✅/❌

**Git Commit** (`config-templates/skills/git-commit.md`):

- Триггер: ключевые слова («закоммить», «commit» и т.д.)
- Шаг 1: `git status && git diff HEAD && git log -n 3 --oneline`
- Шаг 2: определение типа по Conventional Commits
- Шаг 3: `git add` конкретных файлов (не `-A`)
- Шаг 4: генерация черновика сообщения (заголовок en, тело ru)
- Шаг 5: запрос подтверждения
- Шаг 6: `git commit`
- Шаг 7: проверка `git status && git log -n 1`
- Edge cases: нет изменений, нет staged, конфликты, нет git identity, секреты

**Five Whys** (`config-templates/skills/five-whys.md`):

- Триггер: запрос пользователя на анализ проблемы методом «5 почему»
- Пошагово задаёт уточняющие вопросы, углубляясь в корневую причину
- Форматирует результат в виде дерева «почему → ответ»

**Session State Saver** (`config-templates/skills/session-state-saver.md`):

- Триггер: каждые 5–10 сообщений, завершение сессии, запрос «сохрани состояние»
- Формат: JSON в `/workspace/.qwen/session-state.json`
- Содержимое: метаданные сессии, контекст задачи, изменённые файлы, коммиты, заметки
- Восстановление: при возобновлении сессии читает файл и восстанавливает контекст
- Безопасность: не сохраняет секреты и личные данные

#### 10.11. AGENTS.md — реализация

Файл **не хранится в git** (добавлен в `.gitignore`). Шаблон лежит в
`config-templates/agent/AGENTS.md` и копируется при `make install`.

Файл содержит 7 разделов инструкций для AI:

1. **Роль** — AI-ассистент в изолированном контейнере
2. **Обязательное правило: пользовательские скиллы** — читать скиллы из `/workspace/.qwen/skills/` перед началом работы
3. **Правила безопасности** — не запрашивать секреты, не читать за пределами `/workspace`, уважать `.qwenignore`
4. **Правила работы с кодом** — стиль проекта, комментарии, тесты
5. **Доступные инструменты** — только `/workspace`, стандартные утилиты
6. **Стиль общения** — краткость, язык пользователя
7. **Git commit messages** — Conventional Commits, заголовок en, тело ru

---

### 11. Глоссарий

| Термин                   | Определение                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------- |
| **Перекрытие (overlay)** | Блокировка доступа AI к файлу через монтирование пустого Docker volume поверх существующего файла |
| **Секрет**               | Файл, потенциально содержащий учётные данные, ключи, токены                                       |
| **Скилл**                | Markdown-файл с набором инструкций/алгоритмов для AI-ассистента                                   |
| **Launcher**             | Обёртка `bin/qwen-run`, управляющая запуском контейнера                                           |
| **XDG Base Dir**         | Стандарт размещения пользовательских конфигов (`~/.config/`)                                      |
| **Runtime**              | Docker или Podman — среда выполнения контейнеров                                                  |
| **Контейнер проекта**    | Изолированный контейнер `qcc-XXXXXXXX` с уникальным именем по хэшу пути проекта                   |
