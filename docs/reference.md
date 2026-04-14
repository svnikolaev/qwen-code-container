# 📖 Справочник — Qwen Code Container

Подробная документация для тех, кто хочет разобраться глубже.

---

## 📁 Глобальная конфигурация

Все общие данные хранятся в `~/.config/qwen-code-container/`:

| Путь                     | Назначение                                    |
| ------------------------ | --------------------------------------------- |
| `projects/<hash>/.qwen/` | Авторизация и настройки Qwen Code (на проект) |
| `npm/`                   | Кэш npm (не загрязняет проект)                |
| `config/`                | Общие конфиги (не загрязняют проект)          |
| `skills/`                | Глобальные скиллы для AI-агентов              |
| `model`                  | Версия модели по умолчанию                    |
| `oauth/`                 | Данные OAuth-авторизации                      |
| `launches.log`           | История запусков                              |

Хэш проекта — первые 8 символов MD5 от абсолютного пути:

```bash
echo -n "/home/user/my-project" | md5sum | cut -c1-8
# → a1b2c3d4
```

---

## 🎭 Персональный профиль AI

Если вы хотите задать дополнительные инструкции для AI (не привязанные к проекту):

```bash
mkdir -p ~/.config/qwen-code-container/agent-profile/
```

Содержимое автоматически подключается к каждому запуску `qcc`.

| Файл / директория | Назначение |
|---|---|
| `personality.md` | Персональные инструкции для AI (характер, стиль) |
| `prompts/system.md` | Дополнительные системные промпты |
| `skills/` | Персональные скиллы (поверх глобальных) |
| `agent-overrides.md` | Правила поверх AGENTS.md |

Если директория не существует — ничего не происходит (тихий режим).

> ⚠️ **Не кладите `agent-profile/` в репозиторий** — это персональные данные.

---

## 📋 Системный промпт `AGENTS.md`

Если в корне проекта лежит **`AGENTS.md`**, он передаётся AI как набор инструкций.
Это может быть безопасность, стиль кода, правила git commit.

Файл генерируется при `make install` из `config-templates/agent/`
и не хранится в git (локальный, можно редактировать).

---

## 🤖 Модель

Qwen Code — это **клиент**. Модель работает на сервере провайдера.

### Как узнать текущую модель

```bash
qcc --model
make model
```

### Как установить модель

```bash
make set-model MODEL=qwen-coder
```

Модель сохраняется в `~/.config/qwen-code-container/model` и передаётся
как `--model <версия>` при каждом запуске.

---

## 🐳 Версии образов

Образы публикуются на [GitHub Container Registry](https://github.com/QwenLM/qwen-code/pkgs/container/qwen-code).

По умолчанию: `ghcr.io/qwenlm/qwen-code:0.14.3`

Чтобы обновить, измените `IMAGE` в репозитории или передайте при запуске:

```bash
QWEN_IMAGE=ghcr.io/qwenlm/qwen-code:0.15.0 qcc
```

---

## 🔒 Формат `.qwenignore`

Файл `.qwenignore` в корне проекта — перечень файлов, которые AI не увидит.
Работает аналогично `.gitignore`.

### Синтаксис

```qwenignore
# Комментарий
.env                    # точное имя
*.key                   # glob-паттерн
secrets/                # директория
!important.env          # negation — не перекрывать этот файл
```

### Пример

```qwenignore
# Секреты
.env
*.key
*.pem
secrets/
credentials.json

# Тяжёлые директории
node_modules/
.venv/
__pycache__/

# Логи
*.log
logs/
```

---

## 🏗️ Архитектура: Makefile + ops/

Makefile — тонкая обёртка. Вся логика в `ops/`. Скрипты работают **без make**:

```bash
# Самостоятельный вызов
./ops/system.sh install
./ops/image.sh pull
./ops/project.sh setup

# Справка
./ops/project.sh help
```

### Структура

| Скрипт | Команды |
|---|---|
| `ops/common.sh` | Общие переменные (source) |
| `ops/system.sh` | install, uninstall, check-deps |
| `ops/image.sh` | pull, remove, test |
| `ops/project.sh` | setup, config-update, model, container, lint, check |

### Переменные окружения

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `QWEN_IMAGE` | из файла `IMAGE` | Docker-образ |
| `QWEN_CONFIG_NAME` | `qwen-code-container` | Имя папки конфигов |
| `QWEN_MODEL` | `qwen-coder` | Модель по умолчанию |
| `QWEN_MODEL_EXPLICIT` | (пусто) | Флаг явной модели |

---

## 📐 Схема монтирования

| Тип | Хост | Контейнер | Зачем |
|---|---|---|---|
| Проект (rw) | `./` | `/workspace` | AI работает с файлами |
| Кэш npm | `~/.config/.../npm/` | `/home/qwen/.npm` | Не загрязняет проект |
| Конфиги | `~/.config/.../config/` | `/home/qwen/.config/` | Не загрязняют проект |
| Авторизация | `~/.config/.../projects/<hash>/.qwen/` | `/home/qwen/.qwen/` | На проект |
| Скиллы | `~/.config/.../skills/` | `/workspace/.qwen/skills/` | Для AI |
| Задачи | `~/.config/.../projects/<hash>/tasks/` | `/workspace/.qwen/tasks/` | Task Tracker |
| Agent-profile | `~/.config/.../agent-profile/` | `/workspace/.qwen/agent-profile/` | Персональный промпт |
| ENTRYPOINT | `container/entrypoint.sh` | `/entrypoint.sh` | Git config |

---

## 🔧 Переменные окружения bin/qwen-run

| Переменная | Описание |
|---|---|
| `QWEN_IMAGE` | Docker-образ (приоритет выше файла `IMAGE`) |
| `QWEN_CONFIG_NAME` | Имя папки в `~/.config/` |
| `QWEN_MODEL` | Модель для `--model` |
| `QWEN_MODEL_EXPLICIT` | Если задана — модель установлена явно |
| `GIT_CONFIG_NAME` | Имя для git config в контейнере |
| `GIT_CONFIG_EMAIL` | Email для git config в контейнере |
| `HOST_PORT` | Проброс порта (по умолчанию 5173) |
| `CONTAINER_PORT` | Порт в контейнере (по умолчанию 5173) |

---

## 📄 Документация проекта

| Файл | Назначение |
|---|---|
| `docs/specification.md` | Техническое задание |
| `docs/implementation.md` | Описание реализации |
| `docs/MAINTENANCE.md` | Руководство по поддержке |
| `docs/reference.md` | Справочник (этот файл) |
