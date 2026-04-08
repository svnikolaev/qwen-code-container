#!/bin/bash
# bin/docker-entrypoint.sh — настраивает git и shared skills перед запуском qwen

# Если skills нет, а shared-skills есть — создаём symlink
if [ ! -d "/root/.qwen/skills" ] && [ -d "/root/.qwen/shared-skills" ]; then
    ln -s shared-skills /root/.qwen/skills
fi

# Применяем git config с хоста, если переданы переменные
if [ -n "$GIT_CONFIG_NAME" ]; then
    git config --global user.name "$GIT_CONFIG_NAME"
fi
if [ -n "$GIT_CONFIG_EMAIL" ]; then
    git config --global user.email "$GIT_CONFIG_EMAIL"
fi

# Передаём управление основной команде
exec "$@"
