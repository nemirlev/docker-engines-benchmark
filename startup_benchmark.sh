#!/bin/bash

# Конфигурация
RESULTS_DIR="results/startup"
LOGS_DIR="logs"
VERBOSE=false
REPEAT_COUNT=4
CLEANUP=true
ENGINE="all"

# Создаем необходимые директории
mkdir -p "$RESULTS_DIR" "$LOGS_DIR"

# Функция для вывода помощи
show_help() {
    cat << EOF
Использование: $0 [опции] [движок]

Движки:
  docker-desktop    Docker Desktop
  podman-desktop   Podman Desktop
  orbstack         OrbStack
  rancher-desktop  Rancher Desktop
  colima           Colima
  all              Тестировать все движки

Опции:
  -h, --help          Показать эту справку
  -v, --verbose      Подробный вывод
  -o, --output DIR   Указать директорию для результатов (по умолчанию: ./results)
  -r, --repeat N     Количество повторов теста (по умолчанию: 3)
  --no-cleanup       Не удалять движки после тестирования

Примеры:
  $0 docker-desktop             # Тестировать только Docker Desktop
  $0 --repeat 5 orbstack       # Тестировать OrbStack 5 раз
  $0 -v all                    # Тестировать все движки с подробным выводом
EOF
}

# Функция для проверки, запущен ли движок
is_engine_running() {
    local engine=$1
    case $engine in
        "docker-desktop")
            pgrep -f "Docker Desktop" &> /dev/null
            return $?
            ;;
        "podman-desktop")
            pgrep -f "Podman Desktop" &> /dev/null
            return $?
            ;;
        "orbstack")
            pgrep -f "OrbStack" &> /dev/null
            return $?
            ;;
        "rancher-desktop")
            pgrep -f "Rancher Desktop" &> /dev/null
            return $?
            ;;
        "colima")
            colima status 2>/dev/null | grep "running" &> /dev/null
            return $?
            ;;
    esac
}

# Функция для проверки реальной готовности движка
check_engine_ready() {
    local engine=$1
    local timeout=300
    local interval=1
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        case $engine in
            "docker-desktop")
                if docker info >/dev/null 2>&1 && \
                   docker ps >/dev/null 2>&1 && \
                   docker run --rm hello-world >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            "podman-desktop")
                if podman info >/dev/null 2>&1 && \
                   podman ps >/dev/null 2>&1 && \
                   podman run --rm hello-world >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            "orbstack")
                if docker info >/dev/null 2>&1 && \
                   docker ps >/dev/null 2>&1 && \
                   docker run --rm hello-world >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            "rancher-desktop")
                if docker info >/dev/null 2>&1 && \
                   docker ps >/dev/null 2>&1 && \
                   docker run --rm hello-world >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            "colima")
                if docker info >/dev/null 2>&1 && \
                   docker ps >/dev/null 2>&1 && \
                   docker run --rm hello-world >/dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
        
        sleep $interval
        elapsed=$((elapsed + interval))
        
        if [ $VERBOSE = true ]; then
            echo "Ожидание готовности $engine: $elapsed секунд..." >&2
        fi
    done
    
    return 1
}

# Функция для остановки движка
stop_engine() {
    local engine=$1
    echo "Останавливаем $engine..."
    
    case $engine in
        "docker-desktop")
            osascript -e 'quit app "Docker Desktop"'
            ;;
        "podman-desktop")
            osascript -e 'quit app "Podman Desktop"'
            ;;
        "orbstack")
            osascript -e 'quit app "OrbStack"'
            ;;
        "rancher-desktop")
            osascript -e 'quit app "Rancher Desktop"'
            ;;
        "colima")
            colima stop &> /dev/null
            ;;
    esac
    
    # Ждем пока процесс действительно завершится
    local timeout=30
    while is_engine_running "$engine" && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
    done
}

# Функция для запуска движка и измерения времени
start_engine() {
    local engine=$1
    local log_file="$LOGS_DIR/${engine}_startup.log"
    
    echo "Запуск $engine..." >&2
    
    # Начало измерения
    local start_time=$(date +%s.%N)
    
    case $engine in
        "docker-desktop")
            open -a "Docker Desktop" >/dev/null 2>&1
            ;;
        "podman-desktop")
            open -a "Podman Desktop" >/dev/null 2>&1
            ;;
        "orbstack")
            open -a "OrbStack" >/dev/null 2>&1
            ;;
        "rancher-desktop")
            open -a "Rancher Desktop" >/dev/null 2>&1
            ;;
        "colima")
            colima start >/dev/null 2>&1
            ;;
    esac
    
    # Проверяем реальную готовность
    if ! check_engine_ready "$engine"; then
        echo "Ошибка: $engine не готов к работе" >&2
        return 1
    fi
    
    # Конец измерения
    local end_time=$(date +%s.%N)
    local startup_time=$(echo "$end_time - $start_time" | bc)
    
    # Сохраняем дополнительную информацию в лог
    {
        echo "=== Информация о запуске ==="
        echo "Время запуска: $startup_time секунд"
        echo "=== Информация о системе ==="
        case $engine in
            "podman-desktop")
                podman info 2>/dev/null
                ;;
            *)
                docker info 2>/dev/null
                ;;
        esac
    } > "$log_file"
    
    # Возвращаем только время запуска
    echo "$startup_time"
}

# Функция для тестирования одного движка
test_engine() {
    local engine=$1
    local result_file="$RESULTS_DIR/${engine}_startup.json"
    declare -a times=()
    
    echo "Тестирование $engine..."
    
    for i in $(seq 1 $REPEAT_COUNT); do
      echo "Попытка $i из $REPEAT_COUNT"

      # Убеждаемся, что движок остановлен
      if is_engine_running "$engine"; then
          stop_engine "$engine"
          sleep 5  # Даем время на полную остановку
      fi

      # Замеряем время запуска
      local startup_time=$(start_engine "$engine")

      # Проверяем результат
      if [[ $startup_time =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          if [ $i -ne 1 ]; then  # Пропускаем первый запуск
              times+=($startup_time)
              echo "Время запуска: $startup_time секунд"
          else
              echo "Первый запуск пропущен: $startup_time секунд"
          fi
      else
          echo "Ошибка при запуске движка"
          continue
      fi

      # Останавливаем движок после теста
      stop_engine "$engine"

      # Ждем между тестами
      sleep 5
    done
    
    # Генерируем JSON только если есть успешные измерения
    if [ ${#times[@]} -gt 0 ]; then
        # Вычисляем статистику
        local sum=0
        local min=${times[0]}
        local max=${times[0]}
        
        for time in "${times[@]}"; do
            sum=$(echo "$sum + $time" | bc)
            min=$(echo "if ($time < $min) $time else $min" | bc)
            max=$(echo "if ($time > $max) $time else $max" | bc)
        done
        
        local avg=$(echo "scale=3; $sum / ${#times[@]}" | bc)
        
        # Создаем временный JSON-файл с массивом времени
        local times_json=$(printf '%s\n' "${times[@]}" | jq -R . | jq -s .)
        
        # Формируем JSON с результатами
        jq -n \
            --arg engine "$engine" \
            --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --argjson count "${#times[@]}" \
            --arg avg "$avg" \
            --arg min "$min" \
            --arg max "$max" \
            --argjson times "$times_json" \
            '{
                engine: $engine,
                timestamp: $timestamp,
                repeat_count: $count,
                results: {
                    average: ($avg | tonumber),
                    min: ($min | tonumber),
                    max: ($max | tonumber),
                    all_times: $times
                }
            }' > "$result_file"
        
        echo "Результаты сохранены в $result_file"
        
        if [ $VERBOSE = true ]; then
            echo "Содержимое JSON:"
            cat "$result_file"
        fi
    else
        echo "Нет успешных замеров времени запуска"
        return 1
    fi
}

# Парсинг аргументов командной строки
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
        -r | --repeat)
            shift
            REPEAT_COUNT=$1
            ;;
        --no-cleanup)
            CLEANUP=false
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

# Запускаем тесты
if [ "$ENGINE" = "all" ]; then
    for engine in docker-desktop podman-desktop orbstack rancher-desktop colima; do
        test_engine "$engine"
    done
else
    test_engine "$ENGINE"
fi

echo "Тестирование завершено. Результаты в директории $RESULTS_DIR"