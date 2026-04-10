#!/bin/bash
# container/entrypoint.sh — настраивает git перед запуском qwen

# Применяем git config с хоста, если переданы переменные
if [ -n "$GIT_CONFIG_NAME" ]; then
    git config --global user.name "$GIT_CONFIG_NAME"
fi
if [ -n "$GIT_CONFIG_EMAIL" ]; then
    git config --global user.email "$GIT_CONFIG_EMAIL"
fi

# Передаём управление основной команде
exec "$@"
