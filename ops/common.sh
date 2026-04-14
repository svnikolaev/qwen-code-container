# common.sh — общие переменные и утилиты для ops-скриптов
# Источник: /workspace/ops/common.sh
# Вызывать: source "$(dirname "$0")/common.sh"

set -euo pipefail

# ─── Пути ───────────────────────────────────────────────────────────────────
OPS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$OPS_DIR/.." && pwd)"

# ─── Версии ──────────────────────────────────────────────────────────────────
VERSION="$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "unknown")"
IMAGE="$(cat "$PROJECT_DIR/IMAGE")"

# ─── Конфиг ─────────────────────────────────────────────────────────────────
CONFIG_NAME="${QWEN_CONFIG_NAME:-qwen-code-container}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$CONFIG_NAME"
QWEN_MODEL="${QWEN_MODEL:-qwen-coder}"

# ─── Runtime ────────────────────────────────────────────────────────────────
detect_runtime() {
    if command -v podman >/dev/null 2>&1; then
        echo "podman"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo ""
    fi
}

RUNTIME="${RUNTIME:-$(detect_runtime)}"

# ─── Install пути ───────────────────────────────────────────────────────────
BIN_TARGET="$HOME/.local/bin/qcc"
BIN_SOURCE="$PROJECT_DIR/bin/qwen-run"

# ─── Model файл ─────────────────────────────────────────────────────────────
MODEL_FILE="$CONFIG_DIR/model"

# ─── Утилиты ────────────────────────────────────────────────────────────────

# require_runtime — убедиться что runtime установлен
require_runtime() {
    if [ -z "$RUNTIME" ]; then
        echo "❌ Не найден ни Docker, ни Podman. Установите один из них:"
        echo ""
        echo "  Podman (рекомендуется):"
        echo "    Ubuntu/Debian:  sudo apt install podman"
        echo "    Fedora/RHEL:    sudo dnf install podman"
        echo "    Arch Linux:     sudo pacman -S podman"
        echo "    macOS:          brew install podman && podman machine init && podman machine start"
        echo ""
        echo "  Docker:"
        echo "    Ubuntu/Debian:  curl -fsSL https://get.docker.com | sh"
        echo "    Fedora/RHEL:    sudo dnf install docker-ce && sudo systemctl enable --now docker"
        echo "    macOS:          https://docs.docker.com/desktop/install/mac-install/"
        echo ""
        echo "После установки запустите: make install"
        exit 1
    fi
}

# project_hash — MD5 первых 8 символов от пути проекта
project_hash() {
    echo -n "$PROJECT_DIR" | md5sum | cut -d' ' -f1
}

# container_name — имя контейнера для текущего проекта
container_name() {
    local hash
    hash="$(project_hash)"
    echo "qcc-$(echo "$hash" | head -c 8)"
}

# log_info, log_ok, log_warn, log_err
log_info()  { echo "ℹ️  $*"; }
log_ok()    { echo "✅ $*"; }
log_warn()  { echo "⚠️  $*"; }
log_err()   { echo "❌ $*"; }
