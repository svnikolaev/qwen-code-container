.PHONY: help run shell shell-root setup clean install uninstall check-deps pull-image remove-image test-image model set-model config-update version stop

# Runtime detection: podman first (macOS), fallback docker
RUNTIME := $(shell if command -v podman >/dev/null 2>&1; then echo podman; elif command -v docker >/dev/null 2>&1; then echo docker; fi)

# Образ по умолчанию
IMAGE := ghcr.io/qwenlm/qwen-code:0.14.1
PROJECT_DIR := $(shell pwd)

# Версия проекта
VERSION := $(shell cat $(PROJECT_DIR)/VERSION 2>/dev/null || echo "unknown")

# Имя папки с глобальными конфигами
CONFIG_NAME ?= qwen-code-container
CONFIG_DIR := $(HOME)/.config/$(CONFIG_NAME)

# Модель по умолчанию
QWEN_MODEL ?= qwen3.6-plus

BIN_TARGET := $(HOME)/.local/bin/qcc
BIN_SOURCE := $(PROJECT_DIR)/bin/qwen-run

help:
	@echo "Qwen Code Container launcher v$(VERSION)"
	@echo ""
	@echo "Доступные команды:"
	@echo "  make run             - запустить Qwen Code (docker run)"
	@echo "  make shell           - запустить bash в контейнере (от текущего пользователя)"
	@echo "  make shell-root      - подключиться к запущенному qcc (root bash)"
	@echo "  make setup           - создать базовый config.json (OAuth) + скопировать шаблоны"
	@echo "  make config-update   - обновить конфиги из config-templates/ (перезаписать изменения)"
	@echo "  make clean           - удалить ~/.config/$(CONFIG_NAME)"
	@echo "  make install         - установить 'qcc' в PATH"
	@echo "  make uninstall       - удалить symlink из PATH"
	@echo "  make check-deps      - проверить зависимости (docker, jq)"
	@echo "  make pull-image      - скачать образ"
	@echo "  make remove-image    - удалить образ"
	@echo "  make version         - показать версию"
	@echo "  make model           - показать текущую модель"
	@echo "  make set-model       - установить модель (make set-model MODEL=qwen3.6-plus)"
	@echo "  make stop            - остановить запущенный контейнер qcc"
	@echo ""
	@echo "Переменные:"
	@echo "  CONFIG_NAME=$(CONFIG_NAME)   - имя папки конфигов в ~/.config/"
	@echo "  QWEN_MODEL=$(QWEN_MODEL)     - модель для AI"

version:
	@echo "v$(VERSION)"

run:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" QWEN_MODEL_EXPLICIT=1 ./bin/qwen-run

shell:
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	mkdir -p $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen; \
	RUNTIME_OPTS=""; \
	if [ "$(RUNTIME)" = "podman" ]; then \
		RUNTIME_OPTS="--userns=keep-id --group-add keep-groups"; \
	else \
		RUNTIME_OPTS="--user $(shell id -u):$(shell id -g) --group-add keep-groups"; \
	fi; \
	AGENTS_VOL=""; \
	if [ -f "$(PROJECT_DIR)/AGENTS.md" ]; then \
		AGENTS_VOL="-v $(PROJECT_DIR)/AGENTS.md:/workspace/.qwen/AGENTS.md:ro"; \
	elif [ -f "$(CONFIG_DIR)/AGENTS.md" ]; then \
		AGENTS_VOL="-v $(CONFIG_DIR)/AGENTS.md:/workspace/.qwen/AGENTS.md:ro"; \
	fi; \
	$(RUNTIME) run --rm -it $$RUNTIME_OPTS \
		--security-opt label=disable \
		-v $(PROJECT_DIR):/workspace \
		-v $(CONFIG_DIR)/npm:/root/.npm \
		-v $(CONFIG_DIR)/config:/root/.config \
		-v $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen:/root/.qwen \
		-v $(CONFIG_DIR)/skills:/root/.qwen/shared-skills:ro \
		$$AGENTS_VOL \
		-w /workspace \
		--entrypoint /bin/bash \
		$(IMAGE)

shell-root:
	@echo "🔌 Подключение к запущенному контейнеру qcc (root shell)..."
	$(RUNTIME) exec -it -u root qcc /bin/bash

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

config-update:
	@echo "🔄 Обновление конфигов из config-templates/..."
	@# Агент-конфиги → ~/.config/qwen-code-container/
	@if [ -d "config-templates/agent" ] && [ "$$(ls -A config-templates/agent 2>/dev/null)" ]; then \
		for f in config-templates/agent/*; do \
			name=$$(basename "$$f"); \
			if [ -f "$(CONFIG_DIR)/$$name" ]; then \
				if ! cmp -s "$$f" "$(CONFIG_DIR)/$$name"; then \
					cp "$$f" "$(CONFIG_DIR)/$$name"; \
					echo "✅ Обновлён агент-конфиг: $$name"; \
				else \
					echo "📄 $$name без изменений"; \
				fi; \
			else \
				cp "$$f" "$(CONFIG_DIR)/$$name"; \
				echo "✅ Создан агент-конфиг: $$name"; \
			fi \
		done; \
	else \
		echo "⚠️  Агент-конфиги не найдены"; \
	fi
	@# Скиллы → ~/.config/qwen-code-container/skills/
	@if [ -d "config-templates/skills" ] && [ "$$(ls -A config-templates/skills 2>/dev/null)" ]; then \
		for f in config-templates/skills/*.md; do \
			name=$$(basename "$$f"); \
			if [ -f "$(CONFIG_DIR)/skills/$$name" ]; then \
				if ! cmp -s "$$f" "$(CONFIG_DIR)/skills/$$name"; then \
					cp "$$f" "$(CONFIG_DIR)/skills/$$name"; \
					echo "✅ Обновлён скилл: $$name"; \
				else \
					echo "📄 Скилл $$name без изменений"; \
				fi; \
			else \
				cp "$$f" "$(CONFIG_DIR)/skills/$$name"; \
				echo "✅ Создан скилл: $$name"; \
			fi \
		done; \
	else \
		echo "⚠️  Скиллы не найдены"; \
	fi
	@# Шаблоны проекта → ~/.config/qwen-code-container/projects/<hash>/.qwen/
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	if [ -d "config-templates/qwen" ]; then \
		for f in config-templates/qwen/*; do \
			name=$$(basename "$$f"); \
			[ "$$name" = ".gitignore" ] && continue; \
			dest="$(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/$$name"; \
			if [ -f "$$dest" ]; then \
				if ! cmp -s "$$f" "$$dest"; then \
					cp "$$f" "$$dest"; \
					echo "✅ Обновлён шаблон: $$name"; \
				else \
					echo "📄 Шаблон $$name без изменений"; \
				fi; \
			else \
				cp "$$f" "$$dest"; \
				echo "✅ Создан шаблон: $$name"; \
			fi \
		done; \
	fi
	@echo "✅ Конфиги обновлены"

install:
	@echo "🔧 Установка Qwen Code Launcher..."
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@echo "📁 Конфиги: $(CONFIG_DIR)"
	@# Копируем агент-конфиги (AGENTS.md и др.)
	@if [ -d "config-templates/agent" ] && [ "$$(ls -A config-templates/agent 2>/dev/null)" ]; then \
		for f in config-templates/agent/*; do \
			name=$$(basename "$$f"); \
			if [ ! -f "$(CONFIG_DIR)/$$name" ]; then \
				cp "$$f" "$(CONFIG_DIR)/$$name"; \
				echo "✅ Скопирован агент-конфиг: $$name"; \
			else \
				echo "📄 Агент-конфиг $$name уже существует"; \
			fi \
		done; \
	else \
		echo "⚠️  Агент-конфиги не найдены"; \
	fi
	@# Создаём symlink в ~/.local/bin
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
	@# Авто-добавление ~/.local/bin в PATH (macOS → ~/.zshrc, Linux → ~/.bashrc)
	@if [ "$$(uname)" = "Darwin" ]; then \
		RCFILE="$(HOME)/.zshrc"; \
	else \
		RCFILE="$(HOME)/.bashrc"; \
	fi; \
	if ! grep -q '.local/bin' "$$RCFILE" 2>/dev/null; then \
		echo 'export PATH="$$HOME/.local/bin:$$PATH"' >> "$$RCFILE"; \
		echo "✅ Добавлено ~/.local/bin в PATH ($$RCFILE)"; \
		echo "   Выполните: source $$RCFILE"; \
	fi
	@echo ""
	@echo "🎉 Команда для запуска: qcc"

uninstall:
	@rm -f $(BIN_TARGET)
	@echo "✅ Удалено: $(BIN_TARGET)"

check-deps:
	@echo "🔍 Проверка зависимостей..."
	@if [ -z "$(RUNTIME)" ]; then echo "❌ Не найден ни podman, ни docker"; exit 1; fi
	@echo "✅ Runtime: $(RUNTIME)"
	@command -v jq >/dev/null 2>&1 || { echo "✅ jq уже установлен"; }

pull-image:
	@echo "📥 Стягивание образа $(IMAGE)..."
	$(RUNTIME) pull $(IMAGE)

remove-image:
	@echo "🗑️ Удаление образа $(IMAGE)..."
	$(RUNTIME) rmi $(IMAGE) || true

test-image: pull-image
	@echo "🐳 Проверка образа $(IMAGE)..."
	@RUNTIME_OPTS=""; \
	if [ "$(RUNTIME)" = "podman" ]; then RUNTIME_OPTS="--userns=keep-id"; fi; \
	if $(RUNTIME) run --rm $$RUNTIME_OPTS $(IMAGE) qwen --version >/dev/null 2>&1; then \
		echo "✅ Команда 'qwen' работает"; \
	elif $(RUNTIME) run --rm $$RUNTIME_OPTS $(IMAGE) qwen-code --version >/dev/null 2>&1; then \
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

# === Управление контейнером ===

stop:
	@echo "🛑 Остановка контейнера qcc..."
	@if $(RUNTIME) ps --format '{{.Names}}' 2>/dev/null | grep -q '^qcc$$'; then \
		$(RUNTIME) stop qcc >/dev/null 2>&1 && echo "✅ Контейнер qcc остановлен"; \
	else \
		echo "⚠️  Контейнер qcc не запущен"; \
	fi
