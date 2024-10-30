#!/bin/bash

# Конфигурация
VERBOSE=false
TIMEOUT=180  # Таймаут ожидания готовности в секундах

# Функция для логирования
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1"
}

# Функция для проверки установлен ли Homebrew
check_brew() {
    if ! command -v brew &> /dev/null; then
        log "Homebrew не установлен. Устанавливаем..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        log "Homebrew уже установлен"
    fi
}

# Функция для проверки состояния движка
is_engine_running() {
    local engine=$1
    
    # Сначала проверяем процесс
    case $engine in
        "docker-desktop")
            if ! pgrep -f "Docker Desktop" &> /dev/null; then
                return 1
            fi
            # Дополнительно проверяем работоспособность демона
            docker ps &> /dev/null
            return $?
            ;;
        "podman-desktop")
            if ! pgrep -f "Podman Desktop" &> /dev/null; then
                return 1
            fi
            podman ps &> /dev/null
            return $?
            ;;
        "orbstack")
            if ! pgrep -f "OrbStack" &> /dev/null; then
                return 1
            fi
            docker ps &> /dev/null
            return $?
            ;;
        "rancher-desktop")
            if ! pgrep -f "Rancher Desktop" &> /dev/null; then
                return 1
            fi
            docker ps &> /dev/null
            return $?
            ;;
        "colima")
            if ! colima status 2>/dev/null | grep "Running" &> /dev/null; then
                return 1
            fi
            docker ps &> /dev/null
            return $?
            ;;
    esac
}

# Функция для проверки готовности движка
wait_for_engine() {
    local engine=$1
    local start_time=$(date +%s)
    local current_time
    
    log "Ожидание готовности $engine..."
    
    while true; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $TIMEOUT ]; then
            log "Таймаут ожидания готовности $engine"
            return 1
        fi

        case $engine in
            "docker-desktop"|"orbstack"|"rancher-desktop")
                if docker ps &>/dev/null; then
                    log "$engine готов к работе"
                    return 0
                fi
                ;;
            "podman-desktop")
                if podman ps &>/dev/null; then
                    log "$engine готов к работе"
                    return 0
                fi
                ;;
            "colima")
                if docker ps &>/dev/null; then
                    log "$engine готов к работе"
                    return 0
                fi
                ;;
        esac
        
        sleep 5
    done
}

# Функция для запуска движка
start_engine() {
    local engine=$1
    
    if is_engine_running "$engine"; then
        log "$engine уже запущен"
        return 0
    fi
    
    log "Запуск $engine..."
    case $engine in
        "docker-desktop")
            open -a "Docker Desktop"
            ;;
        "podman-desktop")
            open -a "Podman Desktop"
            ;;
        "orbstack")
            open -a "OrbStack"
            ;;
        "rancher-desktop")
            open -a "Rancher Desktop"
            ;;
        "colima")
            colima start
            ;;
        *)
            log "Неизвестный движок: $engine"
            return 1
            ;;
    esac
    
    wait_for_engine "$engine"
    return $?
}

# Функция для остановки движка
stop_engine() {
    local engine=$1
    
    if ! is_engine_running "$engine"; then
        log "$engine уже остановлен"
        return 0
    fi
    
    log "Остановка $engine..."
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
            colima stop
            ;;
        *)
            log "Неизвестный движок: $engine"
            return 1
            ;;
    esac
    
    local timeout=30
    while is_engine_running "$engine" && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
    done
    
    if is_engine_running "$engine"; then
        log "Не удалось остановить $engine"
        return 1
    fi
    
    log "$engine успешно остановлен"
    return 0
}

# Функция для установки движка
install_engine() {
    local engine=$1
    log "Установка $engine..."
    
    case $engine in
        "docker-desktop")
            brew install --cask docker
            ;;
        "podman-desktop")
            brew install podman
            brew install --cask podman-desktop
            brew install podman-compose
            podman machine init
            podman machine start
            podman machine set --rootful
            ;;
        "orbstack")
            brew install --cask orbstack
            ;;
        "rancher-desktop")
            brew install --cask rancher
            ;;
        "colima")
            brew install docker
            brew install docker-compose
            brew install docker-credential-helper
            brew install colima
            ;;
    esac
    
    log "$engine установлен"
}

# Функция для удаления движка
uninstall_engine() {
    local engine=$1
    log "Удаление $engine..."
    
    # Сначала останавливаем если запущен
    if is_engine_running "$engine"; then
        stop_engine "$engine"
    fi
    
    case $engine in
        "docker-desktop")
            brew uninstall --cask docker
            rm -rf ~/Library/Group\ Containers/group.com.docker
            rm -rf ~/Library/Containers/com.docker.*
            rm -rf ~/.docker
            ;;
        "podman-desktop")
            brew uninstall --cask podman-desktop
            brew uninstall podman-compose
            brew uninstall podman
            rm -rf ~/.local/share/containers
            rm -rf ~/.config/containers
            ;;
        "orbstack")
            brew uninstall --cask orbstack
            rm -rf ~/.orbstack
            ;;
        "rancher-desktop")
            brew uninstall --cask rancher
            rm -rf ~/.rd
            rm -rf ~/Library/Application\ Support/rancher-desktop
            ;;
        "colima")
            brew uninstall colima
            brew uninstall docker-compose
            brew uninstall docker-credential-helper
            brew uninstall docker
            rm -rf ~/.colima
            ;;
    esac
    
    log "$engine удален"
}

# Функция для вывода помощи
show_help() {
    cat << EOF
Использование: $0 <действие> <движок>

Действия:
  install   Установить движок
  start     Запустить движок
  stop      Остановить движок
  restart   Перезапустить движок
  uninstall Удалить движок

Движки:
  docker-desktop    Docker Desktop
  podman-desktop    Podman Desktop
  orbstack          OrbStack
  rancher-desktop   Rancher Desktop
  colima            Colima

Опции:
  -h, --help     Показать эту справку
  -v, --verbose  Подробный вывод

Примеры:
  $0 install docker-desktop  # Установить Docker Desktop
  $0 start docker-desktop    # Запустить Docker Desktop
  $0 uninstall docker-desktop # Удалить Docker Desktop
EOF
}

# Парсинг аргументов
ACTION=""
ENGINE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        install|uninstall|start|stop|restart)
            ACTION=$1
            shift
            ;;
        docker-desktop|podman-desktop|orbstack|rancher-desktop|colima)
            ENGINE=$1
            shift
            ;;
        *)
            echo "Неизвестный параметр: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$ACTION" ] || [ -z "$ENGINE" ]; then
    echo "Ошибка: необходимо указать действие и движок"
    show_help
    exit 1
fi

# Проверяем наличие Homebrew для установки/удаления
if [ "$ACTION" = "install" ] || [ "$ACTION" = "uninstall" ]; then
    check_brew
fi

# Выполнение действия
case $ACTION in
    install)
        install_engine "$ENGINE"
        ;;
    uninstall)
        uninstall_engine "$ENGINE"
        ;;
    start)
        start_engine "$ENGINE"
        ;;
    stop)
        stop_engine "$ENGINE"
        ;;
    restart)
        stop_engine "$ENGINE"
        sleep 5
        start_engine "$ENGINE"
        ;;
esac