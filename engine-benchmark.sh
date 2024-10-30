#!/bin/bash

# Конфигурация
RESULTS_DIR="results/engine"
LOGS_DIR="logs"
VENV_DIR=".venv"
VERBOSE=false

# Создаем необходимые директории
mkdir -p "$RESULTS_DIR" "$LOGS_DIR"

setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "Создание виртуального окружения..."
        python3 -m venv "$VENV_DIR"
    fi
    
    echo "Активация виртуального окружения..."
    source "$VENV_DIR/bin/activate"
    
    echo "Установка зависимостей..."
    pip install psutil psutil
}

# Функция для логирования
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1"
    if [ "$VERBOSE" = true ]; then
        echo "[$timestamp] $1" >>"$LOGS_DIR/benchmark.log"
    fi
}

# Функция для полного цикла тестирования одного движка
benchmark_engine() {
    local engine=$1
    log "Начало тестирования $engine"

    # 1. Установка движка
    log "Установка $engine..."
    ./install.sh install "$engine"
    if [ $? -ne 0 ]; then
        log "Ошибка при установке $engine"
        return 1
    fi

    # 2. Тестирование времени запуска
    log "Тестирование времени запуска $engine..."
    ./startup_benchmark.sh -r 4 "$engine"
    if [ $? -ne 0 ]; then
        log "Ошибка при тестировании запуска $engine"
    fi

    # Запускаем движок
    log "Запуск движка $engine..."
    ./install.sh start "$engine" # правильный порядок аргументов
    if [ $? -ne 0 ]; then
        log "Ошибка при запуске $engine"
        return 1
    fi

    # 3. Тестирование сборки образов
    log "Тестирование сборки образов на $engine..."
    ./build_benchmark.sh -c "$engine"
    if [ $? -ne 0 ]; then
        log "Ошибка при тестировании сборки на $engine"
    fi

    # 4. Тестирование ресурсов
    log "Тестирование потребления ресурсов $engine..."
    # Тест в режиме простоя
    ./resource_benchmark.sh -d 60 -i 5 -t idle "$engine"
    # Тест под нагрузкой
    ./resource_benchmark.sh -d 60 -i 5 -t load "$engine"

    # После тестов останавливаем движок
    log "Остановка движка $engine..."
    ./install.sh stop "$engine"

    # 6. Удаление движка
    log "Удаление $engine..."
    ./install.sh "$engine" uninstall
    if [ $? -ne 0 ]; then
        log "Ошибка при удалении $engine"
        return 1
    fi

    # Деактивируем виртуальное окружение
    deactivate 2>/dev/null || true

    log "Тестирование $engine завершено"
}

# Функция для вывода помощи
show_help() {
    cat <<EOF
Использование: $0 [опции] [движок]

Движки:
  docker-desktop    Docker Desktop
  podman-desktop    Podman Desktop
  orbstack          OrbStack
  rancher-desktop   Rancher Desktop
  colima            Colima
  all               Тестировать все движки

Опции:
  -h, --help          Показать эту справку
  -v, --verbose       Подробный вывод
  -o, --output DIR    Указать директорию для результатов (по умолчанию: ./results)

Примеры:
  $0 docker-desktop             # Тестировать только Docker Desktop
  $0 -v all                    # Тестировать все движки с подробным выводом
EOF
}

# Парсинг аргументов
ENGINE="all"
while [ "$1" != "" ]; do
    case $1 in
    -h | --help)
        show_help
        exit 0
        ;;
    -v | --verbose)
        VERBOSE=true
        ;;
    -o | --output)
        shift
        RESULTS_DIR=$1
        ;;
    docker-desktop | podman-desktop | orbstack | rancher-desktop | colima | all)
        ENGINE=$1
        ;;
    *)
        echo "Неизвестный параметр: $1"
        show_help
        exit 1
        ;;
    esac
    shift
done

# Запуск тестирования
log "Начало комплексного тестирования"

if [ "$ENGINE" = "all" ]; then
    for engine in docker-desktop podman-desktop orbstack rancher-desktop colima; do
        benchmark_engine "$engine"
        # Пауза между тестами разных движков
        log "Ожидание 30 секунд перед следующим тестом..."
        sleep 30
    done
else
    benchmark_engine "$ENGINE"
fi

log "Тестирование завершено. Все результаты в директории: $RESULTS_DIR"

# Создаем итоговый отчет со всеми результатами
if [ "$ENGINE" = "all" ]; then
    log "Создание итогового отчета..."
    jq -s '.' "$RESULTS_DIR"/*_complete_benchmark.json >"$RESULTS_DIR/final_report.json"
fi