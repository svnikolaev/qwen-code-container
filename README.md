# Qwen Code Container

Оболочка (launcher) для безопасного запуска AI-ассистента [**Qwen Code**](https://qwen.ai/qwencode) в изолированном контейнере.

## Быстрый старт

1. **Клонируйте проект** в любое место:

   ```bash
   git clone https://github.com/svnikolaev/qwen-code-container.git
   cd qwen-code-container
   ```

2. **Установите глобальную команду `qcc`** (один раз):

   ```bash
   make install
   ```

   При необходимости добавьте `~/.local/bin` в PATH (обычно уже добавлен):

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

- Файл **`.qwenignore`** в корне проекта — перечень файлов с чувствительной информацией.
- Скрипт `bin/qwen-run` — обёртка, которая вычисляет переменные и запускает `docker run` с защитой чувствительных файлов.

### Глобальная конфигурация

Все общие данные хранятся в **`~/.config/qwen-code-container/`**:

| Путь                     | Назначение                                    |
| ------------------------ | --------------------------------------------- |
| `projects/<hash>/.qwen/` | Авторизация и настройки Qwen Code (на проект) |
| `npm/`                   | Кэш npm (не загрязняет проект)                |
| `config/`                | Общие конфиги (не загрязняют проект)          |
| `skills/`                | Глобальные скиллы для AI-агентов              |
| `model`                  | Версия модели по умолчанию                    |

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

### Запуск

`qcc` запускается в терминале в директории проекта:

| Команда         | Действие                                |
| --------------- | --------------------------------------- |
| `qcc`           | запуск Qwen Code в контейнере           |
| `qcc --version` | показать версию launcher и образа       |
| `qcc --help`    | показать справку                        |
| `qcc --model`   | показать текущую модель                 |
| `qcc --debug`   | показать команду запуска без выполнения |
| `make run`      | то же через Makefile                    |

### Управление

`make` запускается в директории проекта Qwen Code Container:

| Команда              | Действие                                     |
| -------------------- | -------------------------------------------- |
| `make shell`         | bash в контейнере (от текущего пользователя) |
| `make shell-root`    | подключиться к запущенному qcc (root shell)  |
| `make setup`         | создать config.json (OAuth) + шаблоны        |
| `make config-update` | обновить конфиги из шаблонов                 |
| `make version`       | показать версию проекта                      |
| `make clean`         | удалить `~/.config/qwen-code-container`      |
| `make install`       | symlink `qcc` → `~/.local/bin/qcc`           |
| `make uninstall`     | удалить symlink                              |
| `make check-deps`    | проверить зависимости (docker, jq)           |
| `make model`         | показать текущую модель                      |
| `make set-model`     | установить модель (`MODEL=qwen3.6-plus`)     |

## Модель

qwen-code — это **клиент**. Модель работает на сервере провайдера Qwen.

### Как узнать текущую модель

```bash
qcc --model         # покажет заданную модель
make model          # то же через make
```

### Как установить модель

```bash
make set-model MODEL=qwen-coder
qcc --model         # проверить
```

Модель сохраняется в `~/.config/qwen-code-container/model` и передаётся как `--model <версия>` при каждом запуске.

### Как убедиться, что используется последняя версия

1. Проверить актуальную версию на [qwen.ai](https://qwen.ai) или в [блоге Qwen](https://qwenlm.github.io/)
2. Установить: `make set-model MODEL=qwen-coder`
3. При выходе новой версии — обновить: `make set-model MODEL=qwen-coder-new`

## Требования

- Docker (или Podman)
- `jq` — требуется только для команд `make` (`sudo apt install jq` / `brew install jq`). Для прямого запуска `qcc` не нужен.

## Устранение неполадок

**Авторизация не сохраняется** — проверьте `~/.config/qwen-code-container/projects/<hash>/.qwen/`.

**В проекте появились `.npm/` или `.config/`** — удалите их, теперь они монтируются из глобального конфига.

**Проблемы с запуском** — убедитесь, что вы в корне проекта (где `Makefile` и `bin/qwen-run`).

## Структура проекта

```
.
├── bin/
│   └── qwen-run              # Тонкая обёртка над docker run (~220 строк)
├── container/
│   └── entrypoint.sh         # Entry-point контейнера: git config + skills
├── config-templates/
│   ├── agent/                # Глобальные конфиги AI-агента
│   ├── qwen/                 # Шаблоны конфигов Qwen
│   └── skills/               # Глобальные скиллы
├── docs/
│   └── ТЕХНИЧЕСКОЕ_ЗАДАНИЕ.md  # Полное ТЗ и описание реализации
├── Makefile                  # Команды управления
├── VERSION                   # Текущая версия проекта
├── .env.example              # Пример переменных окружения
└── .qwenignore.example       # Пример файла перекрытия
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
