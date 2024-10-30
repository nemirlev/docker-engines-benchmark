#!/bin/bash

VENV_DIR=".venv"

# Проверяем наличие Python
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Ошибка: python3 не установлен"
        exit 1
    fi
}

# Создаем и активируем виртуальное окружение
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "Создание виртуального окружения..."
        python3 -m venv "$VENV_DIR"
    fi
    
    echo "Активация виртуального окружения..."
    source "$VENV_DIR/bin/activate"
    
    echo "Установка зависимостей..."
    pip install psutil pandas
}

# Передаем все аргументы в Python скрипт
run_monitor() {
    python monitor.py "$@"
}

# Основной код
check_python
setup_venv
run_monitor "$@"

# Деактивируем виртуальное окружение
deactivate 2>/dev/null || true