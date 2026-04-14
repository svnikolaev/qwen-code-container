#!/usr/bin/env bash
# image.sh — pull, remove, test
# Использование:
#   ./ops/image.sh pull
#   ./ops/image.sh remove
#   ./ops/image.sh test

source "$(dirname "$0")/common.sh"

# ─── pull ───────────────────────────────────────────────────────────────────
do_pull() {
    require_runtime
    echo "📥 Стягивание образа $IMAGE..."
    $RUNTIME pull "$IMAGE"
    log_ok "Образ скачан"
}

# ─── remove ─────────────────────────────────────────────────────────────────
do_remove() {
    require_runtime
    echo "🗑️ Удаление образа $IMAGE..."
    $RUNTIME rmi "$IMAGE" || true
    log_ok "Образ удалён (или не существовал)"
}

# ─── test ───────────────────────────────────────────────────────────────────
do_test() {
    require_runtime
    echo "🐳 Проверка образа $IMAGE..."

    RUNTIME_OPTS=""
    if [ "$RUNTIME" = "podman" ] && [ "$(uname)" != "Darwin" ]; then
        RUNTIME_OPTS="--userns=keep-id --group-add keep-groups"
    fi

    if $RUNTIME run --rm $RUNTIME_OPTS "$IMAGE" qwen --version >/dev/null 2>&1; then
        log_ok "Команда 'qwen' работает"
    elif $RUNTIME run --rm $RUNTIME_OPTS "$IMAGE" qwen-code --version >/dev/null 2>&1; then
        log_ok "Команда 'qwen-code' работает"
    else
        log_err "Не удалось запустить qwen/qwen-code"
        exit 1
    fi
}

# ─── Main ───────────────────────────────────────────────────────────────────
case "${1:-help}" in
    pull)   do_pull ;;
    remove) do_remove ;;
    test)   do_test ;;
    help|--help|-h)
        echo "Использование: ops/image.sh <команда>"
        echo ""
        echo "Команды:"
        echo "  pull   — скачать образ $IMAGE"
        echo "  remove — удалить образ"
        echo "  test   — скачать и проверить работу"
        ;;
    *)
        echo "❌ Неизвестная команда: $1"
        echo "   ops/image.sh help"
        exit 1
        ;;
esac
