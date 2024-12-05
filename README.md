# PostgreSQL and pgAdmin Setup Script

[![CI](https://github.com/{username}/postgres-pgadmin-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/{username}/postgres-pgadmin-docker/actions/workflows/ci.yml)
[![Security Scan](https://github.com/{username}/postgres-pgadmin-docker/actions/workflows/security.yml/badge.svg)](https://github.com/{username}/postgres-pgadmin-docker/actions/workflows/security.yml)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A bash script to automatically set up PostgreSQL and pgAdmin using Docker containers. This script provides an easy way to deploy a PostgreSQL database server along with pgAdmin for database management.

## Prerequisites

- Docker installed on your system
- Docker Compose installed on your system
- Bash shell (Linux/macOS)

## Features

- Automatic PostgreSQL and pgAdmin container setup
- Dynamic port allocation if default ports are in use
- Automatic container networking
- Persistent data storage using Docker volumes
- Secure password management
- Automatic cleanup of configuration files

## Quick Start

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x setup_postgres.sh
   ```
3. Run the script:
   ```bash
   ./setup_postgres.sh
   ```

## Default Configuration

- PostgreSQL:
  - Default Port: 5432 (automatically finds next available port if in use)
  - Username: postgres
  - Password: postgres123456

- pgAdmin:
  - Default Port: 5050 (automatically finds next available port if in use)
  - Email: admin@admin.com
  - Password: pgadmin123456

## Usage Options

```bash
./setup_postgres.sh [OPTIONS]

Options:
  -h, --help                      Show this help message
  -u, --postgres-user USER        Set PostgreSQL username
  -p, --postgres-password PASS    Set PostgreSQL password
  --postgres-port PORT           Set PostgreSQL port
  -e, --pgadmin-email EMAIL       Set pgAdmin email
  -a, --pgadmin-password PASS     Set pgAdmin password
  --pgadmin-port PORT           Set pgAdmin port
  --no-cleanup                   Skip cleanup of existing setup
```

## Connecting to PostgreSQL

1. Access pgAdmin web interface:
   - Open your browser and navigate to `http://localhost:5050` (or the port shown in the script output)
   - Login using the pgAdmin credentials

2. Direct database connection:
   - Host: localhost
   - Port: 5432 (or the port shown in the script output)
   - Username: postgres (or your custom username)
   - Password: postgres123456 (or your custom password)

## Data Persistence

- PostgreSQL data is stored in a Docker volume named `postgres_data`
- pgAdmin configurations are stored in a Docker volume named `pgadmin_data`

## Troubleshooting

1. If you can't connect to PostgreSQL:
   - Check if the containers are running: `docker ps`
   - Verify the ports using: `docker ps` or `netstat -tuln`
   - Check container logs: `docker logs postgres_db`

2. If pgAdmin can't connect to PostgreSQL:
   - Ensure both containers are on the same network
   - Verify the PostgreSQL container is healthy
   - Check pgAdmin logs: `docker logs pgadmin4`

## Clean Up

To remove the setup:

1. Stop and remove containers:
   ```bash
   docker rm -f postgres_db pgadmin4
   ```

2. Remove volumes (WARNING: This will delete all data):
   ```bash
   docker volume rm postgres_data pgadmin_data
   ```

## Security Notes

- Change default passwords in production environments
- Consider using environment variables for sensitive information
- Restrict network access in production environments
- Regular backup of your databases is recommended

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.
