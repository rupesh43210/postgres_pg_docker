#!/usr/bin/env bash

# Exit on error, undefined variables, and propagate pipe errors
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default configuration
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres123456"
POSTGRES_PORT="5432"
PGADMIN_EMAIL="admin@admin.com"
PGADMIN_PASSWORD="pgadmin123456"
PGADMIN_PORT="5050"
POSTGRES_CONTAINER="postgres_db"
PGADMIN_CONTAINER="pgadmin4"
NETWORK_NAME="postgres_network"

# Log functions
log_info() { printf "${GREEN}[INFO] %s${NC}\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN] %s${NC}\n" "$1"; }
log_error() { printf "${RED}[ERROR] %s${NC}\n" "$1" >&2; }

# Check if a port is in use
is_port_in_use() {
    local port=$1
    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Find next available port
find_next_port() {
    local port=$1
    while is_port_in_use "$port"; do
        port=$((port + 1))
    done
    echo "$port"
}

# Help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help                  Show this help message
    -u, --postgres-user         PostgreSQL username (default: postgres)
    -p, --postgres-password     PostgreSQL password (default: postgres123456)
    --postgres-port             PostgreSQL port (default: 5432)
    --pgadmin-email            pgAdmin email (default: admin@admin.com)
    --pgadmin-password         pgAdmin password (default: pgadmin123456)
    --pgadmin-port             pgAdmin port (default: 5050)
    --no-cleanup               Skip cleanup of existing containers

Examples:
    $0                          # Run with default settings
    $0 -u myuser -p mypassword  # Custom PostgreSQL credentials
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--postgres-user)
                POSTGRES_USER="$2"
                shift 2
                ;;
            -p|--postgres-password)
                POSTGRES_PASSWORD="$2"
                shift 2
                ;;
            --postgres-port)
                POSTGRES_PORT="$2"
                shift 2
                ;;
            --pgadmin-email)
                PGADMIN_EMAIL="$2"
                shift 2
                ;;
            --pgadmin-password)
                PGADMIN_PASSWORD="$2"
                shift 2
                ;;
            --pgadmin-port)
                PGADMIN_PORT="$2"
                shift 2
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    # Check password strength
    if [ ${#POSTGRES_PASSWORD} -lt 8 ]; then
        log_error "PostgreSQL password must be at least 8 characters long"
        exit 1
    fi
    
    if [ ${#PGADMIN_PASSWORD} -lt 8 ]; then
        log_error "pgAdmin password must be at least 8 characters long"
        exit 1
    fi

    # Validate port numbers
    if ! [[ $POSTGRES_PORT =~ ^[0-9]+$ ]] || (( POSTGRES_PORT < 1 || POSTGRES_PORT > 65535 )); then
        log_error "Invalid PostgreSQL port: $POSTGRES_PORT"
        exit 1
    fi
    
    if ! [[ $PGADMIN_PORT =~ ^[0-9]+$ ]] || (( PGADMIN_PORT < 1 || PGADMIN_PORT > 65535 )); then
        log_error "Invalid pgAdmin port: $PGADMIN_PORT"
        exit 1
    fi

    # Check and adjust ports if they're in use
    if is_port_in_use "$POSTGRES_PORT"; then
        local new_port=$(find_next_port "$POSTGRES_PORT")
        log_warn "Port $POSTGRES_PORT is in use. Using port $new_port for PostgreSQL instead"
        POSTGRES_PORT=$new_port
    fi
    
    if is_port_in_use "$PGADMIN_PORT"; then
        local new_port=$(find_next_port "$PGADMIN_PORT")
        log_warn "Port $PGADMIN_PORT is in use. Using port $new_port for pgAdmin instead"
        PGADMIN_PORT=$new_port
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
}

# Cleanup existing setup
cleanup() {
    if [ "${NO_CLEANUP:-false}" = true ]; then
        log_info "Skipping cleanup as requested"
        return
    fi
    
    log_info "Cleaning up existing setup..."
    
    # Stop and remove existing containers
    for container in "$POSTGRES_CONTAINER" "$PGADMIN_CONTAINER"; do
        if docker ps -a -q -f name="$container" >/dev/null; then
            log_info "Removing container: $container"
            docker rm -f "$container" >/dev/null 2>&1 || true
        fi
    done
    
    # Remove volumes with force
    log_info "Removing Docker volumes..."
    docker volume rm -f postgres_data pgadmin_data >/dev/null 2>&1 || true
    
    # Remove any dangling volumes
    log_info "Removing any dangling volumes..."
    docker volume prune -f >/dev/null 2>&1 || true
    
    # Remove network
    if docker network ls -q -f name="$NETWORK_NAME" >/dev/null; then
        log_info "Removing network: $NETWORK_NAME"
        docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
    fi

    # Remove any configuration files
    log_info "Removing configuration files..."
    rm -f docker-compose.yml servers.json
}

# Create configuration files
create_config_files() {
    log_info "Creating configuration files..."
    
    # Create docker-compose.yml
    cat > docker-compose.yml << EOL
services:
  postgres:
    image: postgres:latest
    container_name: ${POSTGRES_CONTAINER}
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT}:5432"
    networks:
      - ${NETWORK_NAME}
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: ${PGADMIN_CONTAINER}
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD}
      - PGADMIN_CONFIG_SERVER_MODE=False
    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./servers.json:/pgadmin4/servers.json
    ports:
      - "${PGADMIN_PORT}:80"
    networks:
      - ${NETWORK_NAME}
    restart: unless-stopped
    depends_on:
      - postgres

networks:
  ${NETWORK_NAME}:
    driver: bridge

volumes:
  postgres_data:
  pgadmin_data:
EOL

    # Create servers.json
    cat > servers.json << EOL
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL Server",
            "Group": "Servers",
            "Host": "${POSTGRES_CONTAINER}",
            "Port": 5432,
            "MaintenanceDB": "postgres",
            "Username": "${POSTGRES_USER}",
            "Password": "${POSTGRES_PASSWORD}",
            "SSLMode": "prefer",
            "ConnectTimeout": 10
        }
    }
}
EOL
}

# Start containers
start_containers() {
    log_info "Starting containers..."
    docker compose up -d

    log_info "Waiting for containers to be ready..."
    wait_for_postgres
    wait_for_pgadmin

    log_info "All containers are ready!"
    
    # Clean up configuration files after successful start
    log_info "Cleaning up configuration files..."
    rm -f docker-compose.yml servers.json
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while ! docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
        if [ $attempt -gt $max_attempts ]; then
            log_error "Timeout waiting for PostgreSQL to be ready"
            exit 1
        fi
        sleep 1
        ((attempt++))
    done
}

# Wait for pgAdmin to be ready
wait_for_pgadmin() {
    log_info "Waiting for pgAdmin to be ready..."
    local max_attempts=30
    local attempt=1
    
    while ! curl -s http://localhost:${PGADMIN_PORT} >/dev/null 2>&1; do
        if [ $attempt -gt $max_attempts ]; then
            log_error "Timeout waiting for pgAdmin to be ready"
            exit 1
        fi
        sleep 1
        ((attempt++))
    done
}

# Show connection information
show_connection_info() {
    log_info "Setup completed successfully!"
    log_info "PostgreSQL is running on port $POSTGRES_PORT"
    log_info "pgAdmin is accessible at http://localhost:$PGADMIN_PORT"
    log_info "\nPostgreSQL Credentials:"
    log_info "Username: $POSTGRES_USER"
    log_info "Password: $POSTGRES_PASSWORD"
    log_info "\npgAdmin Credentials:"
    log_info "Email: $PGADMIN_EMAIL"
    log_info "Password: $PGADMIN_PASSWORD"
}

# Main function
main() {
    parse_args "$@"
    check_requirements
    validate_config
    cleanup
    create_config_files
    start_containers
    show_connection_info
}

# Trap cleanup on script exit
trap 'log_error "An error occurred. Cleaning up..."; cleanup; rm -f docker-compose.yml servers.json' ERR

# Run main function with all arguments
main "$@"
