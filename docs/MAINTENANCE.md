# 🛠️ Qwen Code Container — Руководство по поддержке

> Для разработчиков, техподдержки и себя из будущего.
> Здесь не ТЗ, а **практические ответы**: как работает, почему так, что делать когда сломалось.

---

## 📌 Быстрая навигация

- [Как это работает](#как-это-работает)
- [Почему так, а не иначе](#почему-так-а-не-иначе)
- [Обновление версий](#обновление-версий)
- [Типичные проблемы и решения](#типичные-проблемы-и-решения)
- [Структура файлов](#структура-файлов)
- [Скиллы AI](#скиллы-ai)
- [Контейнер и runtime](#контейнер-и-runtime)
- [Глобальная конфигурация](#глобальная-конфигурация)
- [CI/CD и релизы](#cicd-и-релизы)
- [Чеклист перед релизом](#чеклист-перед-релизом)

---

## 🧠 Как это работает

### Концепция

Qwen Code Container — это **оболочка** (launcher) для запуска AI-ассистента Qwen Code в изолированном контейнере. Главная идея: AI видит только файлы проекта, а секреты перекрыты через `.qwenignore`.

### Ключевой принцип

Каждый проект — **уникальный контейнер** с именем `qcc-XXXXXXXX` (первые 8 символов MD5 от пути проекта):

```bash
echo -n "/home/user/my-project" | md5sum
# → a1b2c3d4e5f6...
# Имя контейнера: qcc-a1b2c3d4
```

Это позволяет:
- **Запускать несколько проектов параллельно** — контейнеры не конфликтуют
- **Сохранять сессию** — при повторном запуске предлагается подключиться к существующему контейнеру
- **Автоматически подбирать порты** — если 5173 занят, берётся следующий свободный

---

## 🤔 Почему так, а не иначе

| Решение | Почему так | Альтернативы |
|---|---|---|
| **`IMAGE` файл** для версии образа | Единый источник истины. Makefile читает из него, CI не хардкодит | Хардкодить в Makefile — сложно обновлять |
| **`VERSION` файл** отдельно | Семантическое версионирование проекта ≠ версия образа | Смешивать — путаница |
| **Глобальная директория** `~/.config/qwen-code-container/` | Не загрязнять проект служебными файлами | Держать всё в проекте — мусор в git |
| **`.qwenignore` вместо `.gitignore`** | AI не должен видеть секреты, даже если они в git | `.gitignore` не подходит — AI монтируется иначе |
| **Podman первый, Docker fallback** | Podman не требует демона, лучше для macOS | Только Docker — не работает у всех |
| **Скиллы в Markdown** | LLM легко читает структурированный текст | JSON/YAML — сложнее для человека |
| **`qcc` symlink в `~/.local/bin/`** | Стандартное место для пользовательских бинарников | `/usr/local/bin` — требует sudo |

---

## 🔄 Обновление версий

### Когда вышел новый образ Qwen Code

1. Открой `IMAGE` — замени тег на новый:
   ```
   ghcr.io/qwenlm/qwen-code:0.15.0
   ```

2. Обнови `.env.example`:
   ```
   QWEN_IMAGE=ghcr.io/qwenlm/qwen-code:0.15.0
   ```

3. Обнови `README.md` (секция "Версии образов"):
   ```
   По умолчанию используется: `ghcr.io/qwenlm/qwen-code:0.15.0`
   ```

4. Проверь что `docs/specification.md` и `docs/implementation.md` указывают актуальную `VERSION`

5. **Почему все три файла:** `IMAGE` — для Makefile, `.env.example` — для пользователей, `README` — для документации

### Когда меняешь версию проекта

1. Обнови `VERSION`:
   ```
   0.3.0
   ```

2. Обнови `docs/specification.md` и `docs/implementation.md`:
   ```
   **Версия проекта:** 0.3.0
   ```

3. Если менялся функционал — обнови README

---

## 🔧 Типичные проблемы и решения

### CI не запускается

**Симптом:** Push в `main`, но GitHub Actions не работает.

**Причина:** Workflow настроен на другую ветку.

**Решение:** Проверь `.github/workflows/shellcheck.yml`:
```yaml
on:
  push:
    branches: [main]  # ← должно совпадать с основной веткой
```

---

### Makefile команды не работают

**Симптом:** `make shell`, `make pull-image` и т.д. выдают ошибку `command not found` или пустую строку.

**Причина:** Переменная `$(RUNTIME)` не определена. Она определяется в начале Makefile через `$(shell if command -v podman ...)` — если ни podman, ни docker не установлены, она пустая.

**Решение:**
```bash
# Проверь что runtime установлен
make check-deps

# Если пусто — установи docker или podman
sudo apt install podman
# или
curl -fsSL https://get.docker.com | sh
```

---

### `.qwenignore` не перекрывает файлы

**Симптом:** AI всё равно видит файлы, которые должны быть скрыты.

**Причина:** 
1. Паттерн не совпадает (регистр, путь)
2. Файл добавлен после запуска контейнера
3. Используется symlink — docker монтирует реальную цель

**Решение:**
```bash
# Запусти с --debug чтобы увидеть что монтируется
qcc --debug

# Проверь что .qwenignore существует и содержит паттерн
cat .qwenignore

# Перезапусти контейнер
qcc --new
```

---

### Авторизация не сохраняется

**Симптом:** При каждом запуске нужно заново авторизовываться.

**Причина:** Файл авторизации не попадает в глобальную директорию.

**Решение:**
```bash
# Проверь глобальную директорию
ls -la ~/.config/qwen-code-container/projects/$(echo -n "$(pwd)" | md5sum | cut -d' ' -f1)/.qwen/

# Если пусто — запусти make setup
make setup
```

---

### Контейнер не запускается

**Симптом:** `qcc` выдает ошибку.

**Чеклист:**
1. `make check-deps` — runtime установлен?
2. `make pull-image` — образ скачан?
3. `make test-image` — образ работает?
4. `qcc --debug` — посмотри команду без выполнения

---

### `.bash_history` попал в git

**Симптом:** В `git status` виден `.bash_history`.

**Причина:** Файл был добавлен до того, как попал в `.gitignore`.

**Решение:**
```bash
git rm --cached .bash_history
# Уже добавлено в .gitignore
```

---

## 📁 Структура файлов

### Репозиторий

```
qwen-code-container/
├── bin/
│   └── qwen-run              # Главный launcher-скрипт (~430 строк bash)
│                             # Читаешь это? Он меняет поведение AI.
├── container/
│   └── entrypoint.sh         # Entry-point: git config в контейнере
├── config-templates/         # Шаблоны для make install/setup
│   ├── agent/
│   │   └── AGENTS.md         # Промпт для AI (безопасность, стиль, commits)
│   ├── qwen/
│   │   ├── output-language.md # Отвечать на русском
│   │   └── .gitignore        # Git-игнор для .qwen/
│   └── skills/               # Скиллы AI (markdown-файлы)
├── docs/
│   ├── specification.md      # ТЗ (техническое задание)
│   ├── implementation.md     # Описание реализации
│   └── MAINTENANCE.md        # ← ТЫ ЗДЕСЬ
├── Makefile                  # Цели: install, setup, run, lint, check...
├── IMAGE                     # Образ Docker (единый источник)
├── VERSION                   # Версия проекта
├── .gitignore                # Что не коммитить
├── .env.example              # Переменные окружения (пример)
├── .qwenignore.example       # Паттерны перекрытия (пример)
└── README.md                 # Документация для пользователей
```

### Глобальная директория (`~/.config/qwen-code-container/`)

```
~/.config/qwen-code-container/
├── projects/
│   └── <hash>/               # MD5 от пути проекта, первые 8 символов
│       └── .qwen/
│           ├── config.json   # Авторизация (OAuth)
│           ├── output-language.md
│           └── .gitignore
├── npm/                      # Кэш npm (один на все проекты)
├── config/                   # Общие конфиги
├── skills/                   # Глобальные скиллы (копируются из config-templates/)
├── agent/                    # Агент-конфиги (AGENTS.md и др.)
├── model                     # Текущая модель (файл с текстом)
└── launches.log              # История запусков
```

---

## 🎯 Скиллы AI

### Что такое скиллы

Скиллы — это **инструкции в Markdown**, которые говорят AI как себя вести в определённых ситуациях. Они не код, а текст — LLM читает их как промпт.

### Где находятся

| Путь | Назначение |
|---|---|
| `config-templates/skills/` | Шаблоны в репозитории |
| `~/.config/qwen-code-container/skills/` | Глобальные (копируются при `make install`) |
| `~/.config/qwen-code-container/agent-profile/skills/` | Персональные (поверх глобальных) |

### Текущие скиллы

| Скилл | Файл | Когда срабатывает |
|---|---|---|
| File Consistency Checker | `file-consistency-checker.md` | После обрыва сессии, перед коммитом |
| Git Commit | `git-commit.md` | По запросу «закоммить», «сделай коммит» |
| Five Whys | `five-whys.md` | При анализе корневых причин |
| Session State Saver | `session-state-saver.md` | Каждые 5-10 сообщений, перед завершением |
| Task Tracker | `task-tracker.md` | При разбиении на задачи |

### Как добавить новый скилл

1. Создай файл в `config-templates/skills/имя-скилла.md`
2. Структура файла:
   ```markdown
   # Название скилла

   ## Когда вызывать
   Описание триггера.

   ## Алгоритм
   1. Шаг 1
   2. Шаг 2

   ## Ограничения
   Что нельзя делать.
   ```
3. `make config-update` — скопирует в глобальную директорию
4. Перезапусти `qcc`

---

## 🐳 Контейнер и runtime

### Runtime detection

Makefile определяет runtime так:
```makefile
RUNTIME := $(shell if command -v podman ...; echo podman; elif command -v docker ...; echo docker; fi)
```

**Порядок:** podman → docker → ошибка

### Имя контейнера

```
qcc-$(echo -n "$PROJECT_DIR" | md5sum | cut -c1-8)
```

Пример: `/home/user/project` → `qcc-a1b2c3d4`

### Монтирование

| Тип | Хост | Контейнер | Зачем |
|---|---|---|---|
| Проект (read-write) | `./` | `/workspace` | AI работает с файлами проекта |
| Глобальный npm | `~/.config/.../npm/` | `/home/qwen/.npm` | Кэш npm не в проекте |
| Глобальный config | `~/.config/.../config/` | `/home/qwen/.config/` | Конфиги не в проекте |
| Глобальный .qwen | `~/.config/.../projects/<hash>/.qwen/` | `/home/qwen/.qwen/` | Авторизация на проект |
| Скиллы | `~/.config/.../skills/` | `/home/qwen/.qwen/skills/` | Скиллы AI |
| ENTRYPOINT | `container/entrypoint.sh` | `/entrypoint.sh` | Git config в контейнере |

### .qwenignore overlay

Скрипт `bin/qwen-run` читает `.qwenignore` и для каждого паттерна создаёт **empty volume**:

```bash
-v /workspace/секретный-файл
```

Это стандартный Docker-приём — empty volume перекрывает смонтированный файл из `./`.

**Поддержка negation:** паттерн `!important.env` отменяет перекрытие.

---

## 🚀 CI/CD и релизы

### GitHub Actions

**Workflow:** `.github/workflows/shellcheck.yml`

- **Триггер:** push/PR в `main` по `bin/**`
- **Действие:** запуск `shellcheck --severity=warning` на `bin/qwen-run` и `container/entrypoint.sh`

### Релизы

1. Обнови `VERSION`
2. Обнови `docs/` (specification.md, implementation.md)
3. Обнови `.env.example` и `README.md` если менялся образ
4. `make check` — проверка синтаксиса
5. `make lint` — shellcheck
6. Создай тег: `git tag v0.3.0 && git push origin v0.3.0`

---

## ✅ Чеклист перед релизом

- [ ] `VERSION` обновлён
- [ ] `docs/specification.md` — версия проекта совпадает
- [ ] `docs/implementation.md` — версия проекта совпадает
- [ ] `.env.example` — версия образа совпадает с `IMAGE`
- [ ] `README.md` — версия образа совпадает с `IMAGE`
- [ ] `make check` — синтаксис bash в порядке
- [ ] `make lint` — shellcheck прошёл
- [ ] CI зелёный (push в `main`)
- [ ] `git add` не включает `.qwen/`
- [ ] Коммит в Conventional Commits формате
- [ ] Тег создан и запушен

---

> 💡 **Помни:** этот проект — твоя собственная инфраструктура. Ломаешь его — ломаешь себя.
> Перед каждым изменением: `make check && make lint` и подумай — не сломает ли это запуск контейнера.