# File Consistency Checker

Проверяет консистентность файлов проекта после внесения изменений и коммуникационных сбоев.

## Когда использовать

- После потери связи / обрыва сессии
- Перед коммитом — убедиться, что все файлы в согласованном состоянии
- Когда есть подозрение, что изменения не применились полностью

## Алгоритм проверки

### 1. Структура проекта

Убедись, что все ожидаемые файлы существуют:

```bash
# Основные файлы проекта
for f in Makefile README.md AGENTS.md .gitignore .env.example bin/qwen-run container/entrypoint.sh; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ $f MISSING"
done
```

### 2. Синтаксис Bash

Проверь скрипты на синтаксические ошибки:

```bash
bash -n bin/qwen-run && echo "✅ qwen-run syntax OK" || echo "❌ qwen-run syntax error"
bash -n container/entrypoint.sh && echo "✅ entrypoint syntax OK" || echo "❌ entrypoint syntax error"
```

### 3. Консистентность Makefile

Убедись, что цели Makefile соответствуют реальным файлам:

```bash
# Проверь, что bin/qwen-run исполняемый
[ -x bin/qwen-run ] && echo "✅ qwen-run executable" || echo "❌ qwen-run not executable"
[ -x container/entrypoint.sh ] && echo "✅ entrypoint executable" || echo "❌ entrypoint not executable"
```

### 4. Пары «объявление → файл»

Проверь, что все упоминаемые в Makefile файлы существуют:

```bash
# Из Makefile: BIN_SOURCE
[ -f "bin/qwen-run" ] && echo "✅ BIN_SOURCE exists" || echo "❌ BIN_SOURCE missing"
```

### 5. Глобальные конфиги vs шаблоны

Сравни `config-templates/` с тем, что должно быть в глобальных конфигах:

```bash
# Проверь, что шаблоны не битые
for f in config-templates/qwen/* config-templates/skills/*; do
    [ -f "$f" ] && echo "✅ template: $f" || echo "❌ template missing: $f"
done
```

### 6. Git status

```bash
git status --short
git diff --stat
```

## Автоматическое исправление

Если найдены проблемы:

| Проблема | Действие |
|----------|----------|
| Файл не исполняемый | `chmod +x bin/qwen-run container/entrypoint.sh` |
| Синтаксическая ошибка | Прочитать файл, найти незакрытые кавычки/скобки |
| Файл отсутствует | Восстановить из последнего коммита или переписать |
| Рассинхрон Makefile ↔ скрипт | Обновить Makefile или скрипт |

## Отчёт

После проверки выдай краткий отчёт:

```
📋 Consistency Report
✅ Все файлы на месте
✅ Синтаксис в порядке
✅ Права доступа корректны
❌ Найдено проблем: 0
```
