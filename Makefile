.PHONY: help run refresh show-blocked shell setup clean install uninstall check-deps pull-image remove-image test-image debug

# Образ по умолчанию
IMAGE := ghcr.io/qwenlm/qwen-code:latest
PROJECT_DIR := $(shell pwd)

# Имя папки с глобальными конфигами (можно переопределить: make CONFIG_NAME=my-qwen install)
CONFIG_NAME ?= qwen-code-docker
CONFIG_DIR := $(HOME)/.config/$(CONFIG_NAME)

# Модель по умолчанию (последняя стабильная)
QWEN_MODEL ?= qwen3.6-plus

BIN_TARGET := $(HOME)/.local/bin/qwen
BIN_SOURCE := $(PROJECT_DIR)/bin/qwen-run

# Определение runtime (docker/podman) для shell
define get_runtime_opts
$(shell if docker --version 2>/dev/null | grep -q podman; then echo "--userns=keep-id --security-opt label=disable"; else echo "--user $(shell id -u):$(shell id -g) --group-add keep-groups --security-opt label=disable"; fi)
endef

help:
	@echo "Доступные команды:"
	@echo "  make pull-image      - скачать образ Qwen Code"
	@echo "  make remove-image    - удалить образ Qwen Code"
	@echo "  make test-image      - проверить работоспособность образа (зависит от pull-image)"
	@echo "  make run             - запустить Qwen Code (с защитой)"
	@echo "  make debug           - запустить с показом полной команды docker"
	@echo "  make refresh         - запустить с перевыбором перекрытия"
	@echo "  make show-blocked    - показать перекрытые файлы"
	@echo "  make shell           - запустить bash в контейнере (без защиты)"
	@echo "  make setup           - создать базовый config.json (OAuth)"
	@echo "  make clean           - удалить ~/.config/$(CONFIG_NAME)"
	@echo "  make install         - установить 'qwen' + инициализировать глобальные конфиги"
	@echo "  make uninstall       - удалить глобальную команду"
	@echo "  make check-deps      - проверить и установить jq"
	@echo "  make model           - показать текущую модель"
	@echo "  make set-model       - установить модель (make set-model MODEL=qwen3.6-plus)"
	@echo ""
	@echo "Переменные:"
	@echo "  CONFIG_NAME=$(CONFIG_NAME)   - имя папки конфигов в ~/.config/"
	@echo "  QWEN_MODEL=$(QWEN_MODEL)     - модель для AI"

pull-image:
	@echo "📥 Стягивание образа $(IMAGE)..."
	docker pull $(IMAGE)

remove-image:
	@echo "🗑️ Удаление образа $(IMAGE)..."
	docker rmi $(IMAGE) || true

test-image: pull-image
	@echo "🐳 Проверка образа $(IMAGE)..."
	@RUNTIME_OPTS=""; \
	if docker --version 2>/dev/null | grep -q podman; then RUNTIME_OPTS="--userns=keep-id"; fi; \
	if docker run --rm $$RUNTIME_OPTS $(IMAGE) qwen --version >/dev/null 2>&1; then \
		echo "✅ Команда 'qwen' работает"; \
	elif docker run --rm $$RUNTIME_OPTS $(IMAGE) qwen-code --version >/dev/null 2>&1; then \
		echo "✅ Команда 'qwen-code' работает"; \
	else \
		echo "❌ Не удалось запустить qwen/qwen-code в контейнере"; \
		echo "Попробуйте вручную: docker run --rm $(IMAGE) --help"; \
		exit 1; \
	fi

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
		else echo "❌ Не удалось установить jq. Установите вручную."; exit 1; fi \
	fi

run:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" ./bin/qwen-run

debug:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" ./bin/qwen-run --debug

refresh:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" ./bin/qwen-run --refresh

show-blocked:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_IMAGE="$(IMAGE)" QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" ./bin/qwen-run --show-blocked

model:
	@chmod +x bin/qwen-run 2>/dev/null || true
	@QWEN_CONFIG_NAME="$(CONFIG_NAME)" QWEN_MODEL="$(QWEN_MODEL)" ./bin/qwen-run --model

shell:
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	mkdir -p $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen
	docker run --rm -it \
		$(get_runtime_opts) \
		-v $(PROJECT_DIR):/workspace \
		-v $(CONFIG_DIR)/npm:/root/.npm \
		-v $(CONFIG_DIR)/config:/root/.config \
		-v $(CONFIG_DIR)/projects/$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1)/.qwen:/root/.qwen \
		-v $(CONFIG_DIR)/skills:/root/.qwen/shared-skills:ro \
		-w /workspace \
		--entrypoint /bin/bash \
		$(IMAGE)

setup:
	@PROJECT_HASH=$$(echo -n "$(PROJECT_DIR)" | md5sum | cut -d' ' -f1); \
	mkdir -p $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen; \
	if [ ! -f "$(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/config.json" ]; then \
		echo '{"auth":{"method":"oauth"}}' > $(CONFIG_DIR)/projects/$$PROJECT_HASH/.qwen/config.json; \
		echo "✅ Создан config.json с OAuth для текущего проекта"; \
	else \
		echo "📄 config.json уже существует для текущего проекта"; \
	fi

clean:
	@echo "Удаляем $(CONFIG_DIR)..."
	@rm -rf $(CONFIG_DIR)
	@echo "Готово"

install:
	@echo "🔧 Установка Qwen Code Launcher..."
	@echo ""
	@# 1. Создаём глобальные директории (шареные между проектами)
	@mkdir -p $(CONFIG_DIR)/npm $(CONFIG_DIR)/config $(CONFIG_DIR)/skills
	@echo "📁 Конфиги: $(CONFIG_DIR)"
	@echo "   ├── npm/      — кэш npm (шареный)"
	@echo "   ├── config/   — общие конфиги (шареные)"
	@echo "   └── skills/   — глобальные скиллы (шареные)"
	@echo "   ├── projects/ — проектные .qwen (создаются автоматически)"
	@echo ""
	@# 2. Копируем скиллы из config-templates/skills в глобальный конфиг
	@if [ -d "config-templates/skills" ] && [ "$$(ls -A config-templates/skills 2>/dev/null)" ]; then \
		for skill in config-templates/skills/*.md; do \
			name=$$(basename "$$skill"); \
			if [ ! -f "$(CONFIG_DIR)/skills/$$name" ]; then \
				cp "$$skill" "$(CONFIG_DIR)/skills/$$name"; \
				echo "✅ Скопирован скилл: $$name"; \
			else \
				echo "📄 Скилл $$name уже существует — пропускаем"; \
			fi \
		done; \
	else \
		echo "⚠️  Скиллы в config-templates/skills/ не найдены"; \
	fi
	@# 3. Копируем AGENTS.md как глобальный шаблон
	@if [ -f "AGENTS.md" ]; then \
		if [ ! -f "$(CONFIG_DIR)/AGENTS.md" ]; then \
			cp AGENTS.md "$(CONFIG_DIR)/AGENTS.md"; \
			echo "✅ Скопирован AGENTS.md в глобальные конфиги"; \
		else \
			echo "📄 Глобальный AGENTS.md уже существует — пропускаем"; \
		fi; \
	else \
		echo "⚠️  AGENTS.md не найден в проекте"; \
	fi
	@echo ""
	@# 5. Создаём symlink на бинарник
	@mkdir -p $(HOME)/.local/bin
	@if [ -L "$(BIN_TARGET)" ] && [ "$$(readlink -f "$(BIN_TARGET)")" = "$$(readlink -f "$(BIN_SOURCE)")" ]; then \
		echo "✅ Ссылка уже существует: $(BIN_TARGET)"; \
	elif [ -f "$(BIN_TARGET)" ] || [ -L "$(BIN_TARGET)" ]; then \
		rm -f "$(BIN_TARGET)"; \
		ln -s "$(BIN_SOURCE)" "$(BIN_TARGET)"; \
		echo "✅ Старый файл заменён на ссылку: $(BIN_TARGET)"; \
	else \
		ln -s "$(BIN_SOURCE)" "$(BIN_TARGET)"; \
		echo "✅ Создана ссылка: $(BIN_TARGET) → $(BIN_SOURCE)"; \
	fi
	@echo ""
	@echo "🎉 Готово! Убедитесь, что ~/.local/bin в PATH:"
	@echo '   export PATH="$$HOME/.local/bin:$$PATH"'

uninstall:
	@rm -f $(BIN_TARGET)
	@echo "✅ Удалено: $(BIN_TARGET)"

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
	@echo "   Запустите qwen для применения"
endif