#!/usr/bin/env bash
# project.sh — setup, config-update, model, container (stop/shell), lint, check
# Использование:
#   ./ops/project.sh setup
#   ./ops/project.sh config-update
#   ./ops/project.sh model [set <version>]
#   ./ops/project.sh container stop
#   ./ops/project.sh container shell
#   ./ops/project.sh lint
#   ./ops/project.sh check

source "$(dirname "$0")/common.sh"

# ─── setup ──────────────────────────────────────────────────────────────────
do_setup() {
    local hash
    hash="$(project_hash)"
    local project_config="$CONFIG_DIR/projects/$hash/.qwen"
    mkdir -p "$project_config"

    if [ ! -f "$project_config/config.json" ]; then
        echo '{"auth":{"method":"oauth"}}' > "$project_config/config.json"
        log_ok "Создан config.json с OAuth"
    else
        echo "📄 config.json уже существует"
    fi

    if [ -d "$PROJECT_DIR/config-templates/qwen" ]; then
        for f in "$PROJECT_DIR/config-templates/qwen"/*; do
            name="$(basename "$f")"
            [ "$name" = ".gitignore" ] && continue
            if [ ! -f "$project_config/$name" ]; then
                cp "$f" "$project_config/$name"
                log_ok "Скопирован шаблон: $name"
            fi
        done
    fi
}

# ─── config-update ─────────────────────────────────────────────────────────
do_config_update() {
    echo "🔄 Обновление конфигов из config-templates/..."

    # Агент-конфиги → ~/.config/qwen-code-container/
    if [ -d "$PROJECT_DIR/config-templates/agent" ] && [ "$(ls -A "$PROJECT_DIR/config-templates/agent" 2>/dev/null)" ]; then
        for f in "$PROJECT_DIR/config-templates/agent"/*; do
            name="$(basename "$f")"
            if [ -f "$CONFIG_DIR/$name" ]; then
                if ! cmp -s "$f" "$CONFIG_DIR/$name"; then
                    cp "$f" "$CONFIG_DIR/$name"
                    log_ok "Обновлён агент-конфиг: $name"
                else
                    echo "📄 $name без изменений"
                fi
            else
                cp "$f" "$CONFIG_DIR/$name"
                log_ok "Создан агент-конфиг: $name"
            fi
        done
    else
        log_warn "Агент-конфиги не найдены"
    fi

    # Скиллы → ~/.config/qwen-code-container/skills/
    if [ -d "$PROJECT_DIR/config-templates/skills" ] && [ "$(ls -A "$PROJECT_DIR/config-templates/skills" 2>/dev/null)" ]; then
        for f in "$PROJECT_DIR/config-templates/skills"/*.md; do
            name="$(basename "$f")"
            if [ -f "$CONFIG_DIR/skills/$name" ]; then
                if ! cmp -s "$f" "$CONFIG_DIR/skills/$name"; then
                    cp "$f" "$CONFIG_DIR/skills/$name"
                    log_ok "Обновлён скилл: $name"
                else
                    echo "📄 Скилл $name без изменений"
                fi
            else
                cp "$f" "$CONFIG_DIR/skills/$name"
                log_ok "Создан скилл: $name"
            fi
        done
    else
        log_warn "Скиллы не найдены"
    fi

    # Шаблоны проекта → ~/.config/qwen-code-container/projects/<hash>/.qwen/
    local hash
    hash="$(project_hash)"
    if [ -d "$PROJECT_DIR/config-templates/qwen" ]; then
        for f in "$PROJECT_DIR/config-templates/qwen"/*; do
            name="$(basename "$f")"
            [ "$name" = ".gitignore" ] && continue
            local dest="$CONFIG_DIR/projects/$hash/.qwen/$name"
            if [ -f "$dest" ]; then
                if ! cmp -s "$f" "$dest"; then
                    cp "$f" "$dest"
                    log_ok "Обновлён шаблон: $name"
                else
                    echo "📄 Шаблон $name без изменений"
                fi
            else
                cp "$f" "$dest"
                log_ok "Создан шаблон: $name"
            fi
        done
    fi

    log_ok "Конфиги обновлены"
}

# ─── model ─────────────────────────────────────────────────────────────────
do_model() {
    local subcmd="${1:-show}"
    local model_version="${2:-}"

    case "$subcmd" in
        show|"")
            if [ -f "$MODEL_FILE" ]; then
                echo "🤖 Текущая модель: $(cat "$MODEL_FILE")"
            else
                echo "🤖 Модель не задана (используется по умолчанию от провайдера)"
            fi
            echo "   Makefile default: $QWEN_MODEL"
            echo "   Изменить: ops/project.sh model set qwen-coder"
            ;;
        set)
            if [ -z "$model_version" ]; then
                log_err "Укажите модель: ops/project.sh model set qwen-coder"
                exit 1
            fi
            mkdir -p "$CONFIG_DIR"
            echo "$model_version" > "$MODEL_FILE"
            log_ok "Модель установлена: $model_version"
            echo "   Сохранено в $MODEL_FILE"
            ;;
        *)
            log_err "Неизвестная подкоманда: $subcmd"
            echo "   ops/project.sh model [set <version>]"
            exit 1
            ;;
    esac
}

# ─── container ─────────────────────────────────────────────────────────────
do_container() {
    local subcmd="${1:-help}"

    case "$subcmd" in
        stop)
            require_runtime
            echo "🛑 Остановка контейнеров qcc..."
            STOPPED=0
            for name in $($RUNTIME ps --format '{{.Names}}' 2>/dev/null | grep '^qcc-'); do
                $RUNTIME stop "$name" >/dev/null 2>&1 && STOPPED=1
            done
            if [ "$STOPPED" -eq 1 ]; then
                log_ok "Контейнеры qcc остановлены"
            else
                log_warn "Нет запущенных контейнеров qcc"
            fi
            ;;
        shell)
            require_runtime
            local cname
            cname="$(container_name)"
            if $RUNTIME ps --format '{{.Names}}' 2>/dev/null | grep -q "^${cname}$"; then
                echo "🔌 Подключение к контейнеру $cname (root shell)..."
                $RUNTIME exec -it -u root "$cname" /bin/bash
            else
                log_warn "Контейнер $cname не запущен. Запустите qcc в этом проекте."
                exit 1
            fi
            ;;
        help|--help|-h)
            echo "Использование: ops/project.sh container <команда>"
            echo ""
            echo "Команды:"
            echo "  stop   — остановить все контейнеры qcc-*"
            echo "  shell  — подключиться к контейнеру этого проекта"
            ;;
        *)
            log_err "Неизвестная команда: $subcmd"
            echo "   ops/project.sh container help"
            exit 1
            ;;
    esac
}

# ─── lint ───────────────────────────────────────────────────────────────────
do_lint() {
    echo "🔍 Запуск shellcheck..."
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_err "shellcheck не установлен. Установите: sudo apt install shellcheck"
        exit 1
    fi
    shellcheck --severity=warning "$PROJECT_DIR/bin/qwen-run" "$PROJECT_DIR/container/entrypoint.sh"
    log_ok "shellcheck прошёл без ошибок"
}

# ─── check ─────────────────────────────────────────────────────────────────
do_check() {
    echo "🔍 Проверка синтаксиса bash скриптов..."
    bash -n "$PROJECT_DIR/bin/qwen-run" && log_ok "bin/qwen-run — синтаксис в порядке"
    bash -n "$PROJECT_DIR/container/entrypoint.sh" && log_ok "container/entrypoint.sh — синтаксис в порядке"
    log_ok "Все скрипты синтаксически корректны"
}

# ─── Main ───────────────────────────────────────────────────────────────────
case "${1:-help}" in
    setup)          do_setup ;;
    config-update)  do_config_update ;;
    model)          shift; do_model "$@" ;;
    container)      shift; do_container "$@" ;;
    lint)           do_lint ;;
    check)          do_check ;;
    help|--help|-h)
        echo "Использование: ops/project.sh <команда> [аргументы]"
        echo ""
        echo "Команды:"
        echo "  setup              — создать config.json (OAuth) + шаблоны"
        echo "  config-update      — обновить конфиги из config-templates/"
        echo "  model              — показать текущую модель"
        echo "  model set <версия> — установить модель"
        echo "  container stop     — остановить контейнеры qcc-*"
        echo "  container shell    — подключиться к контейнеру (root bash)"
        echo "  lint               — запустить shellcheck"
        echo "  check              — проверить синтаксис bash скриптов"
        ;;
    *)
        log_err "Неизвестная команда: $1"
        echo "   ops/project.sh help"
        exit 1
        ;;
esac
