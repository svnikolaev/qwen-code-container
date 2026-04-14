.PHONY: help run clean health version \
        install uninstall check-deps \
        setup config-update \
        pull-image remove-image test-image \
        model set-model \
        stop shell \
        lint check

PROJECT_DIR := $(shell pwd)
VERSION := $(shell cat $(PROJECT_DIR)/VERSION 2>/dev/null || echo "unknown")
IMAGE := $(shell cat $(PROJECT_DIR)/IMAGE)
CONFIG_NAME ?= qwen-code-container
CONFIG_DIR := $(shell echo "$${XDG_CONFIG_HOME:-$$HOME/.config}/$(CONFIG_NAME)")
QWEN_MODEL ?= qwen-coder

OPS := ./ops

# ─── Справка ─────────────────────────────────────────────────────────────
help:
	@echo "Qwen Code Container launcher v$(VERSION)"
	@echo ""
	@echo "Доступные команды:"
	@echo "  make run             - запустить Qwen Code (docker run)"
	@echo "  make shell           - подключиться к контейнеру этого проекта (root bash)"
	@echo "  make setup           - создать базовый config.json (OAuth) + скопировать шаблоны"
	@echo "  make config-update   - обновить конфиги из config-templates/ (перезаписать изменения)"
	@echo "  make clean           - удалить ~/.config/$(CONFIG_NAME)"
	@echo "  make install         - установить 'qcc' в PATH"
	@echo "  make uninstall       - удалить symlink из PATH"
	@echo "  make check-deps      - проверить зависимости (docker, jq)"
	@echo "  make pull-image      - скачать образ"
	@echo "  make remove-image    - удалить образ"
	@echo "  make test-image      - скачать и проверить работу образа"
	@echo "  make version         - показать версию"
	@echo "  make model           - показать текущую модель"
	@echo "  make set-model       - установить модель (make set-model MODEL=qwen-coder)"
	@echo "  make stop            - остановить запущенный контейнер qcc"
	@echo "  make health          - диагностика состояния"
	@echo "  make lint            - запустить shellcheck"
	@echo "  make check           - проверить синтаксис bash скриптов"
	@echo ""
	@echo "Переменные:"
	@echo "  CONFIG_NAME=$(CONFIG_NAME)   - имя папки конфигов в ~/.config/"
	@echo "  QWEN_MODEL=$(QWEN_MODEL)     - модель для AI"

# ─── Запуск ───────────────────────────────────────────────────────────────
version:
	@echo "v$(VERSION)"

run:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" QWEN_MODEL_EXPLICIT=1 ./bin/qwen-run

health:
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" QWEN_MODEL_EXPLICIT=1 ./bin/qwen-run --health

# ─── Очистка ──────────────────────────────────────────────────────────────
clean:
	@echo "Удаляем $(CONFIG_DIR)..."
	@rm -rf $(CONFIG_DIR)
	@echo "Готово"

# ─── Ops-скрипты ──────────────────────────────────────────────────────────
install:
	@$(OPS)/system.sh install

uninstall:
	@$(OPS)/system.sh uninstall

check-deps:
	@$(OPS)/system.sh check-deps

setup:
	@$(OPS)/project.sh setup

config-update:
	@$(OPS)/project.sh config-update

model:
	@$(OPS)/project.sh model

set-model:
ifndef MODEL
	@echo "❌ Укажите модель: make set-model MODEL=qwen-coder"
	@exit 1
else
	@$(OPS)/project.sh model set "$(MODEL)"
endif

pull-image:
	@$(OPS)/image.sh pull

remove-image:
	@$(OPS)/image.sh remove

test-image:
	@$(OPS)/image.sh test

stop:
	@$(OPS)/project.sh container stop

shell:
	@$(OPS)/project.sh container shell

lint:
	@$(OPS)/project.sh lint

check:
	@$(OPS)/project.sh check
