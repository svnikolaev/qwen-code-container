#!/usr/bin/env bash
# system.sh — install, uninstall, check-deps
# Использование:
#   ./ops/system.sh install
#   ./ops/system.sh uninstall
#   ./ops/system.sh check-deps

source "$(dirname "$0")/common.sh"

# ─── install ────────────────────────────────────────────────────────────────
do_install() {
    require_runtime

    echo "🔧 Установка Qwen Code Launcher..."

    mkdir -p "$CONFIG_DIR"/npm "$CONFIG_DIR"/config "$CONFIG_DIR"/skills
    echo "📁 Конфиги: $CONFIG_DIR"

    # Копируем агент-конфиги
    if [ -d "$PROJECT_DIR/config-templates/agent" ] && [ "$(ls -A "$PROJECT_DIR/config-templates/agent" 2>/dev/null)" ]; then
        for f in "$PROJECT_DIR/config-templates/agent"/*; do
            name="$(basename "$f")"
            if [ ! -f "$CONFIG_DIR/$name" ]; then
                cp "$f" "$CONFIG_DIR/$name"
                log_ok "Скопирован агент-конфиг: $name"
            else
                echo "📄 Агент-конфиг $name уже существует"
            fi
        done
    else
        log_warn "Агент-конфиги не найдены"
    fi

    # Создаём symlink
    mkdir -p "$HOME/.local/bin"
    if [ -L "$BIN_TARGET" ] && [ "$(readlink -f "$BIN_TARGET")" = "$(readlink -f "$BIN_SOURCE")" ]; then
        log_ok "Ссылка уже существует: $BIN_TARGET"
    elif [ -f "$BIN_TARGET" ] || [ -L "$BIN_TARGET" ]; then
        rm -f "$BIN_TARGET"
        ln -s "$BIN_SOURCE" "$BIN_TARGET"
        log_ok "Обновлена ссылка: $BIN_TARGET"
    else
        ln -s "$BIN_SOURCE" "$BIN_TARGET"
        log_ok "Создана ссылка: $BIN_TARGET"
    fi

    # Авто-добавление ~/.local/bin в PATH
    if [ "$(uname)" = "Darwin" ]; then
        RCFILE="$HOME/.zshrc"
    else
        RCFILE="$HOME/.bashrc"
    fi
    if ! grep -q '.local/bin' "$RCFILE" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RCFILE"
        log_ok "Добавлено ~/.local/bin в PATH ($RCFILE)"
        echo "   Выполните: source $RCFILE"
    fi
    echo ""
    echo "🎉 Команда для запуска: qcc"
}

# ─── uninstall ──────────────────────────────────────────────────────────────
do_uninstall() {
    rm -f "$BIN_TARGET"
    log_ok "Удалено: $BIN_TARGET"
}

# ─── check-deps ─────────────────────────────────────────────────────────────
do_check_deps() {
    echo "🔍 Проверка зависимостей..."
    require_runtime
    log_ok "Runtime: $RUNTIME"
    if command -v jq >/dev/null 2>&1; then
        log_ok "jq уже установлен"
    else
        echo "ℹ️  jq не найден (нужен только для make-целей)"
    fi
}

# ─── Main ───────────────────────────────────────────────────────────────────
case "${1:-help}" in
    install)      do_install ;;
    uninstall)    do_uninstall ;;
    check-deps)   do_check_deps ;;
    help|--help|-h)
        echo "Использование: ops/system.sh <команда>"
        echo ""
        echo "Команды:"
        echo "  install      — установить qcc в PATH"
        echo "  uninstall    — удалить symlink из PATH"
        echo "  check-deps   — проверить зависимости (docker/podman, jq)"
        ;;
    *)
        echo "❌ Неизвестная команда: $1"
        echo "   ops/system.sh help"
        exit 1
        ;;
esac
