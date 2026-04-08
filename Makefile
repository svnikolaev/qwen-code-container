.PHONY: help run shell setup clean install uninstall check-deps pull-image remove-image test-image model set-model

# Образ по умолчанию
IMAGE := ghcr.io/qwenlm/qwen-code:0.14.0
PROJECT_DIR := $(shell pwd)

# Имя папки с глобальными конфигами
CONFIG_NAME ?= qwen-code-docker
CONFIG_DIR := $(HOME)/.config/$(CONFIG_NAME)

# Модель по умолчанию
QWEN_MODEL ?= qwen3.6-plus

BIN_TARGET := $(HOME)/.local/bin/qwen
BIN_SOURCE := $(PROJECT_DIR)/bin/qwen-run

help:
	@echo "Доступные команды:"
	@echo "  make run             - запустить Qwen Code (docker compose)"
	@echo "  make shell           - запустить bash в контейнере"
	@echo "  make setup           - создать базовый config.json (OAuth) + скопировать шаблоны"
	@echo "  make clean           - удалить ~/.config/$(CONFIG_NAME)"
	@echo "  make install         - установить 'qwen' в PATH"
	@echo "  make uninstall       - удалить symlink из PATH"
	@echo "  make check-deps      - проверить зависимости (docker, jq)"
	@echo "  make pull-image      - скачать образ"
	@echo "  make remove-image    - удалить образ"
	@echo "  make model           - показать текущую модель"
	@echo "  make set-model       - установить модель (make set-model MODEL=qwen3.6-plus)"
	@echo ""
	@echo "Переменные:"
	@echo "  CONFIG_NAME=$(CONFIG_NAME)   - имя папки конфигов в ~/.config/"
	@echo "  QWEN_MODEL=$(QWEN_MODEL)     - модель для AI"

run:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" QWEN_MODEL_EXPLICIT=1 ./bin/qwen-run

shell:
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	mkdir -p $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen; \
	RUNTIME_OPTS=""; \
	if docker --version 2>/dev/null | grep -qi podman; then \
		RUNTIME_OPTS="--userns=keep-id --group-add keep-groups"; \
	else \
		RUNTIME_OPTS="--user $(shell id -u):$(shell id -g) --group-add keep-groups"; \
	fi; \
	docker run --rm -it $$RUNTIME_OPTS \
		--security-opt label=disable \
		-v $(PROJECT_DIR):/workspace \
		-v $(CONFIG_DIR)/npm:/root/.npm \
		-v $(CONFIG_DIR)/config:/root/.config \
		-v $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen:/root/.qwen \
		-v $(CONFIG_DIR)/skills:/root/.qwen/shared-skills:ro \
		-w /workspace \
		--entrypoint /bin/bash \
		$(IMAGE)

setup:
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	mkdir -p $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen; \
	if [ ! -f "$(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/config.json" ]; then \
		echo '{"auth":{"method":"oauth"}}' > $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/config.json; \
		echo "✅ Создан config.json с OAuth"; \
	else \
		echo "📄 config.json уже существует"; \
	fi; \
	if [ -d "config-templates/qwen" ]; then \
		for f in config-templates/qwen/*; do \
			name=$$(basename "$$f"); \
			[ "$$name" = ".gitignore" ] && continue; \
			if [ ! -f "$(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/$$name" ]; then \
				cp "$$f" "$(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/$$name"; \
				echo "✅ Скопирован шаблон: $$name"; \
			fi \
		done; \
	fi

clean:
	@echo "Удаляем $(CONFIG_DIR)..."
	@rm -rf $(CONFIG_DIR)
	@echo "Готово"

install:
	@echo "🔧 Установка Qwen Code Launcher..."
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@echo "📁 Конфиги: $(CONFIG_DIR)"
	@# Копируем скиллы из проекта
	@if [ -d "config-templates/skills" ] && [ "$$(ls -A config-templates/skills 2>/dev/null)" ]; then \
		for skill in config-templates/skills/*.md; do \
			name=$$(basename "$$skill"); \
			if [ ! -f "$(CONFIG_DIR)/skills/$$name" ]; then \
				cp "$$skill" "$(CONFIG_DIR)/skills/$$name"; \
				echo "✅ Скопирован скилл: $$name"; \
			else \
				echo "📄 Скилл $$name уже существует"; \
			fi \
		done; \
	else \
		echo "⚠️  Скиллы не найдены"; \
	fi
	@# Копируем AGENTS.md
	@if [ -f "AGENTS.md" ]; then \
		if [ ! -f "$(CONFIG_DIR)/AGENTS.md" ]; then \
			cp AGENTS.md "$(CONFIG_DIR)/AGENTS.md"; \
			echo "✅ Скопирован AGENTS.md"; \
		else \
			echo "📄 AGENTS.md уже существует"; \
		fi; \
	fi
	@# Создаём symlink
	@mkdir -p $(HOME)/.local/bin
	@if [ -L "$(BIN_TARGET)" ] && [ "$$(readlink -f "$(BIN_TARGET)")" = "$$(readlink -f "$(BIN_SOURCE)")" ]; then \
		echo "✅ Ссылка уже существует: $(BIN_TARGET)"; \
	elif [ -f "$(BIN_TARGET)" ] || [ -L "$(BIN_TARGET)" ]; then \
		rm -f "$(BIN_TARGET)"; \
		ln -s "$(BIN_SOURCE)" "$(BIN_TARGET)"; \
		echo "✅ Обновлена ссылка: $(BIN_TARGET)"; \
	else \
		ln -s "$(BIN_SOURCE)" "$(BIN_TARGET)"; \
		echo "✅ Создана ссылка: $(BIN_TARGET)"; \
	fi
	@echo ""
	@echo "🎉 Убедитесь, что ~/.local/bin в PATH:"
	@echo '   export PATH="$$HOME/.local/bin:$$PATH"'

uninstall:
	@rm -f $(BIN_TARGET)
	@echo "✅ Удалено: $(BIN_TARGET)"

check-deps:
	@echo "🔍 Проверка зависимостей..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker не найден"; exit 1; }
	@if command -v jq >/dev/null 2>&1; then \
		echo "✅ jq уже установлен"; \
	else \
		echo "⚠️  jq не найден. Устанавливаем..."; \
		if command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y jq; \
		elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y jq; \
		elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --noconfirm jq; \
		elif command -v brew >/dev/null 2>&1; then brew install jq; \
		else echo "❌ Не удалось установить jq"; exit 1; fi \
	fi

pull-image:
	@echo "📥 Стягивание образа $(IMAGE)..."
	docker pull $(IMAGE)

remove-image:
	@echo "🗑️ Удаление образа $(IMAGE)..."
	docker rmi $(IMAGE) || true

test-image: pull-image
	@echo "🐳 Проверка образа $(IMAGE)..."
	@RUNTIME_OPTS=""; \
	if docker --version 2>/dev/null | grep -qi podman; then RUNTIME_OPTS="--userns=keep-id"; fi; \
	if docker run --rm $$RUNTIME_OPTS $(IMAGE) qwen --version >/dev/null 2>&1; then \
		echo "✅ Команда 'qwen' работает"; \
	elif docker run --rm $$RUNTIME_OPTS $(IMAGE) qwen-code --version >/dev/null 2>&1; then \
		echo "✅ Команда 'qwen-code' работает"; \
	else \
		echo "❌ Не удалось запустить qwen/qwen-code"; \
		exit 1; \
	fi

# === Модель ===

MODEL_FILE := $(CONFIG_DIR)/model

model:
	@if [ -f "$(MODEL_FILE)" ]; then \
		echo "🤖 Текущая модель: $$(cat $(MODEL_FILE))"; \
	else \
		echo "🤖 Модель не задана (используется по умолчанию от провайдера)"; \
	fi
	@echo "   Makefile default: $(QWEN_MODEL)"
	@echo "   Изменить: make set-model MODEL=qwen3.6-plus"

set-model:
ifndef MODEL
	@echo "❌ Укажите модель: make set-model MODEL=qwen3.6-plus"
	@exit 1
else
	@mkdir -p $(CONFIG_DIR)
	@echo "$(MODEL)" > $(MODEL_FILE)
	@echo "✅ Модель установлена: $(MODEL)"
	@echo "   Сохранено в $(MODEL_FILE)"
endif
