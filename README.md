# Qwen Code Container

Оболочка (launcher) для безопасного запуска AI-ассистента [**Qwen Code**](https://qwen.ai/qwencode) в изолированном контейнере.

## Быстрый старт

1. **Клонируйте проект:**

   ```bash
   git clone https://github.com/svnikolaev/qwen-code-container.git
   cd qwen-code-container
   ```

2. **Установите команду `qcc`** (один раз):

   ```bash
   make install
   ```

   Добавьте `~/.local/bin` в PATH, если ещё не добавлен:

   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Настройте авторизацию** (один раз):

   ```bash
   make setup
   ```

4. **Запустите в любом проекте:**

   ```bash
   cd ~/my-project
   qcc
   ```

## Как работает защита

Файл **`.qwenignore`** в корне проекта — перечень файлов, которые AI не увидит.
Скрипт `bin/qwen-run` запускает контейнер, перекрывая эти файлы.

Каждый проект получает уникальный контейнер `qcc-XXXXXXXX` (MD5 от пути).
Можно запускать несколько проектов параллельно — контейнеры не конфликтуют.

Подробности: [docs/reference.md](docs/reference.md)

## Команды

### qcc — запуск в проекте

| Команда           | Действие                                         |
| ----------------- | ------------------------------------------------ |
| `qcc`             | запустить Qwen Code в контейнере                 |
| `qcc --attach`    | подключиться к сессии                            |
| `qcc --new`       | перезапустить контейнер                          |
| `qcc --stop`      | остановить все контейнеры qcc-*                   |
| `qcc --model`     | показать текущую модель                          |
| `qcc --health`    | диагностика                                      |
| `qcc --debug`     | показать команду запуска                         |

### make — управление (в директории проекта-контейнера)

| Команда              | Действие                                   |
| -------------------- | ------------------------------------------ |
| `make install`       | установить `qcc` в PATH                    |
| `make uninstall`     | удалить symlink                            |
| `make setup`         | создать OAuth + шаблоны                    |
| `make config-update` | обновить конфиги из шаблонов               |
| `make model`         | показать модель                            |
| `make set-model`     | установить модель                          |
| `make check`         | проверить синтаксис bash скриптов          |
| `make lint`          | запустить shellcheck                       |
| `make check-deps`    | проверить зависимости                      |
| `make stop`          | остановить все контейнеры                   |
| `make shell`         | подключиться к контейнеру (root bash)      |
| `make version`       | показать версию                            |
| `make clean`         | удалить глобальные конфиги                 |
| `make help`          | полная справка                             |

## Скиллы AI

Скиллы — инструкции, которые управляют поведением AI:

| Скилл | Назначение |
|---|---|
| File Consistency Checker | Проверка целостности после сбоев |
| Git Commit | Автоматизация коммитов |
| Five Whys | Анализ корневых причин |
| Session State Saver | Сохранение состояния сессии |
| Task Tracker | Разбиение на задачи, журнал |

Новые скиллы из репозитория устанавливаются командой:

```bash
make config-update
```

## Требования

- **Docker** или **Podman**
- `jq` — нужен только для make-команд

## Устранение неполадок

| Проблема | Решение |
|---|---|
| Авторизация не сохраняется | Проверьте `~/.config/qwen-code-container/projects/<hash>/.qwen/` |
| Появились `.npm/` или `.config/` в проекте | Удалите, теперь они монтируются из глобального конфига |
| Не запускается | Убедитесь, что вы в корне проекта (где `.qwenignore`) |

## Документация

| Файл | Назначение |
|---|---|
| [docs/reference.md](docs/reference.md) | Справочник — глобальные конфиги, модель, .qwenignore, архитектура |
| [docs/specification.md](docs/specification.md) | Техническое задание |
| [docs/implementation.md](docs/implementation.md) | Описание реализации |
| [docs/MAINTENANCE.md](docs/MAINTENANCE.md) | Руководство по поддержке |

## Лицензия

MIT — см. [LICENSE](LICENSE).
