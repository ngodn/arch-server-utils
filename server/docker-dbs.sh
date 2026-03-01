#!/bin/bash
# Docker DBs: Quick database containers (MySQL, PostgreSQL, Redis, etc.)
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Docker Databases..."

# Check docker is available
if ! command -v docker &>/dev/null; then
  error "Docker is required. Select the Docker component first."
  return 0
fi

# Database definitions
DB_NAMES=("MySQL 8.4" "PostgreSQL 18" "MariaDB 11.8" "Redis 7" "MongoDB" "MSSQL 2022")
DB_SELECTED=(0 0 0 0 0 0)

show_db_menu() {
  echo
  info "Select databases to run as Docker containers:"
  echo

  for i in "${!DB_NAMES[@]}"; do
    local num=$((i + 1))
    if (( DB_SELECTED[i] )); then
      printf "   ${GREEN}[x]${NC} %d) %s\n" "$num" "${DB_NAMES[$i]}"
    else
      printf "   ${DIM}[ ] %d) %s${NC}\n" "$num" "${DB_NAMES[$i]}"
    fi
  done

  echo
  echo -e "  ${DIM}Note: MySQL and MariaDB both use port 3306 — pick one.${NC}"
  echo -e "  Toggle: ${BOLD}[1-6]${NC}  All: ${BOLD}[a]${NC}  Done: ${BOLD}[d]${NC}  Skip: ${BOLD}[s]${NC}"
}

while true; do
  show_db_menu
  read -rp "  > " db_choice

  case $db_choice in
    [1-6])
      db_idx=$((db_choice - 1))
      DB_SELECTED[$db_idx]=$(( ! DB_SELECTED[db_idx] ))
      ;;
    a|A) for i in "${!DB_SELECTED[@]}"; do DB_SELECTED[$i]=1; done ;;
    d|D) break ;;
    s|S) success "Skipped database setup"; return 0 ;;
  esac
done

# Install selected databases
for i in "${!DB_NAMES[@]}"; do
  if (( DB_SELECTED[i] )); then
    case $i in
      0)
        info "Starting MySQL 8.4..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:3306:3306" --name=mysql8 \
          -e MYSQL_ROOT_PASSWORD= -e MYSQL_ALLOW_EMPTY_PASSWORD=true \
          mysql:8.4 && success "MySQL 8.4 on port 3306" || warn "MySQL failed (container may already exist)"
        ;;
      1)
        info "Starting PostgreSQL 18..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:5432:5432" --name=postgres18 \
          -e POSTGRES_HOST_AUTH_METHOD=trust \
          postgres:18 && success "PostgreSQL 18 on port 5432" || warn "PostgreSQL failed (container may already exist)"
        ;;
      2)
        info "Starting MariaDB 11.8..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:3306:3306" --name=mariadb11 \
          -e MARIADB_ROOT_PASSWORD= -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=true \
          mariadb:11.8 && success "MariaDB 11.8 on port 3306" || warn "MariaDB failed (container may already exist)"
        ;;
      3)
        info "Starting Redis 7..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:6379:6379" --name=redis \
          redis:7 && success "Redis 7 on port 6379" || warn "Redis failed (container may already exist)"
        ;;
      4)
        info "Starting MongoDB..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:27017:27017" --name=mongodb \
          -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=admin123 \
          mongo:noble && success "MongoDB on port 27017 (admin/admin123)" || warn "MongoDB failed (container may already exist)"
        ;;
      5)
        info "Starting MSSQL 2022..."
        sudo docker run -d --restart unless-stopped \
          -p "127.0.0.1:1433:1433" --name=mssql \
          -e MSSQL_PID=Developer -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=@dmin123" \
          mcr.microsoft.com/mssql/server:2022-CU12-ubuntu-22.04 && success "MSSQL 2022 on port 1433 (sa/@dmin123)" || warn "MSSQL failed (container may already exist)"
        ;;
    esac
  fi
done

success "Docker databases configured"
