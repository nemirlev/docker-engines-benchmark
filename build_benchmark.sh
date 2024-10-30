#!/bin/bash

# Конфигурация
TESTS_DIR="test-builds"
ENGINE=""
LOGS_DIR="logs/build"

# Функция для вывода помощи
show_help() {
    # Получаем список доступных тестов
    available_tests=$(list_available_tests)
    
    cat << EOF
Использование: $0 [опции] [тест]

Доступные тесты:
$(echo "$available_tests" | sed 's/^/  /')
  all        Запустить все тесты

Опции:
  -h, --help          Показать эту справку
  -c, --clean        Очистить кэш Docker перед сборкой
  -v, --verbose      Подробный вывод
  -o, --output DIR   Указать директорию для результатов (по умолчанию: ./results)
  --no-cache         Отключить использование кэша при сборке
  --list            Показать список доступных тестов

Примеры:
  $0 simple                    # Запустить только simple тест
  $0 --clean all              # Запустить все тесты с очисткой кэша
  $0 --verbose java           # Запустить java тест с подробным выводом
  $0 -o /tmp/results ml       # Сохранить результаты в указанную директорию

EOF
}

# Функция для получения списка доступных тестов
list_available_tests() {
    if [ ! -d "$TESTS_DIR" ]; then
        echo "Директория $TESTS_DIR не найдена"
        return 1
    fi
    
    # Ищем все директории, содержащие Dockerfile
    find "$TESTS_DIR" -type f -name "Dockerfile" | while read dockerfile; do
        dirname "${dockerfile#$TESTS_DIR/}" | cut -d'/' -f1
    done | sort | uniq
}

# Функция для проверки существования теста
check_test_exists() {
    local test_type=$1
    if [ ! -f "$TESTS_DIR/$test_type/Dockerfile" ]; then
        echo "Ошибка: Тест '$test_type' не найден в $TESTS_DIR"
        echo "Доступные тесты:"
        list_available_tests
        return 1
    fi
    return 0
}

# Функция для измерения времени сборки
measure_build_time() {
    local test_type=$1
    local context_dir="$TESTS_DIR/$test_type"
    local log_file="$LOGS_DIR/${test_type}_build.log"
    local result_file="$RESULTS_DIR/${test_type}_result.json"

    local build_command="docker"
    if ! command -v docker &> /dev/null && command -v podman &> /dev/null; then
        build_command="podman"
    fi
    
    # Проверяем существование теста
    check_test_exists "$test_type" || return 1
    
    echo "Начинаем тест сборки: $test_type"
    echo "Используется Dockerfile из: $context_dir"
    
    # Создаем необходимые директории
    mkdir -p "$LOGS_DIR" "$RESULTS_DIR"
    
    # Очищаем кэш если требуется
    if [ "$CLEAN_CACHE" = true ]; then
        echo "Очищаем кэш Docker..."
        $build_command builder prune -f > /dev/null
    fi
    
    # Подготавливаем параметры сборки
    local build_opts=""
    if [ "$NO_CACHE" = true ]; then
        build_opts="$build_opts --no-cache"
    fi
    if [ "$VERBOSE" = true ]; then
        build_opts="$build_opts --progress=plain"
    fi
    
    # Замеряем время
    local start_time=$(date +%s.%N)

    if [ "$VERBOSE" = true ]; then
        $build_command build $build_opts -t "benchmark-$test_type" "$context_dir" 2>&1 | tee "$log_file"
    else
        $build_command build $build_opts -t "benchmark-$test_type" "$context_dir" > "$log_file" 2>&1
    fi
    
    local build_status=${PIPESTATUS[0]}
    local end_time=$(date +%s.%N)
    
    # Проверяем статус сборки
    if [ $build_status -ne 0 ]; then
        echo "Ошибка при сборке $test_type"
        echo "Проверьте лог: $log_file"
        return 1
    fi
    
    # Вычисляем время сборки
    local build_time=$(echo "$end_time - $start_time" | bc)
    
    # Получаем информацию о размере образа
    local image_size=$($build_command images "benchmark-$test_type" --format "{{.Size}}")
    
    # Сохраняем результаты в JSON
    cat > "$result_file" << EOF
{
    "test_type": "$test_type",
    "build_time": $build_time,
    "image_size": "$image_size",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "build_options": {
        "clean_cache": $CLEAN_CACHE,
        "no_cache": $NO_CACHE,
        "verbose": $VERBOSE
    }
}
EOF
    
    echo "Тест $test_type завершен за $build_time секунд"
    echo "Размер образа: $image_size"
    echo "Результаты сохранены в: $result_file"
    echo "Лог сборки: $log_file"
}

# Парсинг аргументов командной строки
CLEAN_CACHE=false
VERBOSE=false
NO_CACHE=false
TEST_TYPE="all"
ENGINE=""

while [ "$1" != "" ]; do
    case $1 in
        -h | --help)
            show_help
            exit 0
            ;;
        --list)
            echo "Доступные тесты:"
            list_available_tests
            exit 0
            ;;
        -c | --clean)
            CLEAN_CACHE=true
            ;;
        -v | --verbose)
            VERBOSE=true
            ;;
        --no-cache)
            NO_CACHE=true
            ;;
        -o | --output)
            shift
            RESULTS_DIR=$1
            ;;
        docker-desktop | podman-desktop | orbstack | rancher-desktop | colima)
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

# Проверяем наличие директории с тестами
if [ ! -d "$TESTS_DIR" ]; then
    echo "Ошибка: Директория $TESTS_DIR не найдена"
    exit 1
fi

# После парсинга аргументов добавьте:
if [ -z "$ENGINE" ]; then
    echo "Ошибка: не указан движок (docker-desktop, podman-desktop, orbstack, rancher-desktop, colima)"
    exit 1
fi

RESULTS_DIR="results/build/${ENGINE}"

# Выполнение тестов
if [ "$TEST_TYPE" = "all" ]; then
    echo "Запуск всех доступных тестов..."
    list_available_tests | while read test; do
        measure_build_time "$test"
    done
else
    measure_build_time "$TEST_TYPE"
fi

echo "Тестирование завершено. Все результаты в директории: $RESULTS_DIR"