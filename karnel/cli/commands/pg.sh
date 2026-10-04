#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

# Variáveis globais do PostgreSQL
: "${PREFIX:=/data/data/com.termux/files/usr}"
PG_DATA_DEFAULT="$PREFIX/var/lib/postgresql"
PG_LOG="$KARNEL_CACHE/postgresql.log"
# Termux PostgreSQL creates the superuser role from the OS user, not "postgres".
PG_USER="$(id -un 2>/dev/null || whoami 2>/dev/null || echo postgres)"
PGPORT="5432"
# Prefer the local Unix socket; fall back to TCP only when the socket is absent.
if [[ -d "$PREFIX/var/run/postgresql" ]]; then
	PGHOST="$PREFIX/var/run/postgresql"
else
	PGHOST="localhost"
fi
export PGUSER="$PG_USER" PGPORT="$PGPORT" PGHOST="$PGHOST" PGDATABASE="postgres"

# Função para exportar variáveis de ambiente do PostgreSQL
pg_export_env() {
	local data_dir="$1"
	if [[ -n "$data_dir" ]]; then
		export PGDATA="$data_dir"
		export PGUSER="$PG_USER"
		export PGPORT="5432"
		export PGHOST="$PGHOST"
		export PGDATABASE="postgres"
		# Adicionar binários do PostgreSQL ao PATH se necessário
		if [[ -d "$PREFIX/bin" ]]; then
			export PATH="$PREFIX/bin:$PATH"
		fi
	fi
}

# Detectar e exportar diretório de dados do PostgreSQL
pg_detect_data() {
	local data_dirs=(
		"$PREFIX/var/lib/postgresql"
		"$PREFIX/var/lib/postgresql/data"
		"$PG_DATA_DEFAULT"
		"$PG_DATA_DEFAULT/data"
		"$HOME/.termux/postgresql"
		"$HOME/.termux/postgresql/data"
	)

	for dir in "${data_dirs[@]}"; do
		if [[ -d "$dir" ]] && [[ -f "$dir/PG_VERSION" ]]; then
			PG_DATA="$dir"
			pg_export_env "$dir"
			return 0
		fi
	done

	return 1
}

# Mostrar ajuda
pg_help() {
	echo
	box "Karnel PostgreSQL Manager"
	echo
	log_info "Usage: karnel pg <command> [options]"
	echo
	separator_section "Available Commands"
	echo
	printf "    ${D_CYAN}%-12s${NC} %s\n" "start" "Start PostgreSQL server"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "stop" "Stop PostgreSQL server"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "restart" "Restart PostgreSQL server"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "status" "Check PostgreSQL status"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "init" "Initialize PostgreSQL database"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "create" "Create a new database"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "drop" "Drop a database"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "backup" "Backup a database with compression & checksum"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "restore" "Restore a database from a compressed file"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "list-backups" "List available database backups"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "schedule" "Schedule automatic backups via cron"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "list" "List all databases"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "shell" "Open psql shell"
	echo
}

# Verificar se PostgreSQL está instalado
check_pg_installed() {
	if ! command -v pg_ctl &>/dev/null; then
		log_error "PostgreSQL is not installed"
		log_info "Run: ${D_CYAN}karnel install db${NC}"
		return 1
	fi
	return 0
}

# Verificar se está inicializado
check_pg_initialized() {
	pg_detect_data && [[ -f "$PG_DATA/PG_VERSION" ]]
}

# Inicializar PostgreSQL
pg_init() {
	separator
	box "Initializing PostgreSQL"
	separator
	echo

	check_pg_installed || return 1

	# Verificar se já está inicializado
	if check_pg_initialized; then
		log_warn "PostgreSQL is already initialized"
		echo
		list_item "Data directory: $PG_DATA"
		list_item "Run: ${D_CYAN}karnel pg start${NC}"
		echo
		return 0
	fi

	mkdir -p "$PG_DATA_DEFAULT"

	log_info "Initializing PostgreSQL database..."
	echo

	# Executar initdb
	if loading "Initializing database" initdb -D "$PG_DATA_DEFAULT" -E UTF8 --locale=C.UTF-8; then
		local os_user; os_user=$(whoami 2>/dev/null || id -un 2>/dev/null || echo "unknown")
		log_success "PostgreSQL initialized successfully"
		echo
		list_item "Data directory: $PG_DATA_DEFAULT"
		list_item "Superuser role: $PG_USER (the Termux OS user)"
		echo
		log_info "Start PostgreSQL with: ${D_CYAN}karnel pg start${NC}"
	else
		log_error "Failed to initialize PostgreSQL"
		log_warn "Check log: $PG_LOG"
		return 1
	fi

	echo
}

# Iniciar PostgreSQL
pg_start() {
	separator
	box "Starting PostgreSQL"
	separator
	echo

	check_pg_installed || return 1

	# Detectar diretório de dados
	if ! pg_detect_data; then
		log_warn "PostgreSQL not initialized yet"
		log_info "Initializing first..."
		mkdir -p "$PG_DATA_DEFAULT"
		if ! loading "Initializing database" initdb -D "$PG_DATA_DEFAULT" -E UTF8 --locale=C.UTF-8; then
			log_error "Failed to initialize PostgreSQL"
			log_warn "Check log: $PG_LOG"
			return 1
		fi
		pg_export_env "$PG_DATA_DEFAULT"
		PG_DATA="$PG_DATA_DEFAULT"
	fi

	log_info "Starting PostgreSQL server..."
	echo

	# Iniciar servidor e verificar se funcionou
	if loading "Starting PostgreSQL" pg_ctl -D "${PG_DATA:-$PGDATA}" -l "$PG_LOG" start 2>&1; then
		sleep 2
		# Verificar se realmente está rodando
		if pg_ctl -D "${PG_DATA:-$PGDATA}" status &>/dev/null; then
			log_success "PostgreSQL started successfully"
			echo
			list_item "Listening on: localhost:5432"
			list_item "User: $PG_USER"
		else
			log_error "PostgreSQL failed to start"
			log_warn "Check log: $PG_LOG"
			return 1
		fi
	else
		log_error "Failed to start PostgreSQL"
		log_warn "Check log: $PG_LOG"
		return 1
	fi

	echo
}

# Detener PostgreSQL
pg_stop() {
	separator
	box "Stopping PostgreSQL"
	separator
	echo

	check_pg_installed || return 1

	# Detectar diretório de dados
	if ! pg_detect_data; then
		log_warn "PostgreSQL is not initialized"
		return 0
	fi

	log_info "Stopping PostgreSQL server..."
	echo

	if loading "Stopping PostgreSQL" pg_ctl -D "$PG_DATA" stop 2>&1; then
		log_success "PostgreSQL stopped successfully"
	else
		log_warn "PostgreSQL may not be running or failed to stop"
		return 1
	fi

	echo
}

# Reiniciar PostgreSQL
pg_restart() {
	separator
	box "Restarting PostgreSQL"
	separator
	echo

	check_pg_installed || return 1

	# Detectar diretório de dados
	if ! pg_detect_data; then
		log_warn "PostgreSQL not initialized yet"
		log_info "Initializing first..."
		pg_init || return 1
		sleep 1
	else
		pg_stop || return 1
		sleep 1
	fi

	pg_start || return 1

	echo
	separator
	log_success "PostgreSQL restarted"
	separator
	echo
}

# Estado de PostgreSQL
pg_status() {
	separator
	box "PostgreSQL Status"
	separator
	echo

	check_pg_installed || return 1

	# Detectar diretório de dados
	if pg_detect_data && [[ -f "$PG_DATA/PG_VERSION" ]]; then
		if pg_ctl -D "$PG_DATA" status &>/dev/null; then
			log_success "PostgreSQL is RUNNING"
			echo
			list_item "Data directory: $PG_DATA"
			list_item "Port: 5432"
			list_item "User: $PG_USER"
		else
			log_warn "PostgreSQL is STOPPED"
			echo
			list_item "Data directory: $PG_DATA"
			list_item "Run: ${D_CYAN}karnel pg start${NC}"
		fi
	else
		log_warn "PostgreSQL is NOT INITIALIZED"
		echo
		list_item "Run: ${D_CYAN}karnel pg init${NC} to initialize the database"
		list_item "Then run: ${D_CYAN}karnel pg start${NC} to start the server"
	fi

	echo
}

# Criar base de dados
pg_create() {
	local db_name="$1"

	if [[ -z "$db_name" ]]; then
		log_error "Database name required"
		log_info "Usage: karnel pg create <database_name>"
		return 1
	fi

	check_pg_installed || return 1

	# Detectar diretório de dados e exportar variáveis
	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	log_info "Creating database: $db_name..."

	if createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$db_name" 2>&1; then
		log_success "Database '$db_name' created successfully"
	else
		log_error "Failed to create database '$db_name'"
		log_warn "Check that PostgreSQL is running (karnel pg status) and the pg_user role exists"
		return 1
	fi
}

# Eliminar base de dados
pg_drop() {
	local db_name="$1"

	if [[ -z "$db_name" ]]; then
		log_error "Database name required"
		log_info "Usage: karnel pg drop <database_name>"
		return 1
	fi

	check_pg_installed || return 1

	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	log_warn "This will permanently delete database: $db_name"

	read_confirm "Are you sure?" CONFIRM n
	if [[ "$CONFIRM" != "y" ]]; then
		log_warn "Operation cancelled"
		return 0
	fi

	log_info "Dropping database: $db_name..."

	if dropdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$db_name" 2>&1; then
		log_success "Database '$db_name' dropped successfully"
	else
		log_error "Failed to drop database '$db_name'"
		return 1
	fi
}

# Listar bases de dados
pg_list() {
	separator
	box "PostgreSQL Databases"
	separator
	echo

	check_pg_installed || return 1

	# Detectar diretório de dados
	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	log_info "Listing databases..."
	echo

	# Usar psql com variáveis de ambiente corretas
	if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c '\l' 2>&1; then
		echo
	else
		echo
		log_error "Failed to list databases"
		log_warn "Check that PostgreSQL is running (karnel pg status) and the pg_user role exists"
		return 1
	fi
}

# Abrir shell psql
pg_shell() {
	check_pg_installed || return 1

	# Detectar diretório de dados
	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	if [[ -z "$PGDATA" ]]; then
		log_error "PGDATA not set. PostgreSQL may not be properly configured"
		return 1
	fi

	log_info "Opening psql shell..."
	echo

	# Executar psql com variáveis corretas
	psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"
}

# Função principal
pg_main() {
	local cmd="$1"
	shift || true

	case "$cmd" in
	--help|-h)
		pg_help
		return
		;;
	start)
		pg_start
		;;
	stop)
		pg_stop
		;;
	restart)
		pg_restart
		;;
	status)
		pg_status
		;;
	init)
		pg_init
		;;
	create)
		pg_create "$1"
		;;
	drop)
		pg_drop "$1"
		;;
	backup)
		pg_backup "$@"
		;;
	restore)
		pg_restore_db "$@"
		;;
	list-backups | backups)
		pg_list_backups
		;;
	schedule)
		pg_schedule
		;;
	list | ls)
		pg_list
		;;
	shell | psql)
		pg_shell
		;;
	"")
		pg_help
		;;
	*)
		log_error "Unknown command: $cmd"
		pg_help
		return 1
		;;
	esac
}

_run_backup_cmd() {
	local db_name="$1"
	local file_path="$2"
	local _bs_ret=0
	set -o pipefail
	pg_dump -d "$db_name" -F c -b 2>/dev/null | gzip > "$file_path" || _bs_ret=$?
	set +o pipefail
	return $_bs_ret
}

_run_restore_cmd() {
	local db_name="$1"
	local file_path="$2"
	local _rs_ret=0
	set -o pipefail
	gunzip -c "$file_path" | pg_restore -d "$db_name" -c 2>>"${KARNEL_CACHE:-$HOME/.cache/karnel}/karnel-pg.log" || _rs_ret=$?
	set +o pipefail
	return $_rs_ret
}

_pg_cleanup_old_backups() {
	local db_name="$1"
	local backup_dir="$KARNEL_DATA/pg_backups"
	local retention_limit=10

	local -a backups=()
	while IFS= read -r f; do
		if [[ -n "$f" ]]; then
			backups+=("$f")
		fi
	done < <(find "$backup_dir" -name "${db_name}_*.backup.gz" -type f 2>/dev/null | sort)

	local count=${#backups[@]}
	if (( count > retention_limit )); then
		local to_delete=$(( count - retention_limit ))
		log_info "Cleaning up $to_delete old backup(s)..."
		for ((i=0; i<to_delete; i++)); do
			rm -f "${backups[$i]}" "${backups[$i]}.sha256"
			list_item "Deleted: $(basename "${backups[$i]}")"
		done
	fi
}

pg_backup() {
	check_pg_installed || return 1
	local db_name="$1"
	if [[ -z "$db_name" ]]; then
		read_input "Enter database name to backup" db_name
	fi
	if [[ -z "$db_name" ]]; then
		log_error "No database name provided"
		return 1
	fi

	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	log_info "Creating compressed backup for '$db_name'..."
	local backup_dir="$KARNEL_DATA/pg_backups"
	mkdir -p "$backup_dir"
	local safe_db_name
	safe_db_name=$(printf '%s' "$db_name" | tr -c '[:alnum:]_.-' '_')
	[[ -n "$safe_db_name" ]] || { log_error "Invalid database name"; return 1; }
	local file_name="${safe_db_name}_$(date +%Y%m%d_%H%M%S).backup.gz"
	local file_path="$backup_dir/$file_name"

	if loading "Running backup dump" _run_backup_cmd "$db_name" "$file_path"; then
		sha256sum "$file_path" | cut -d' ' -f1 > "${file_path}.sha256"
		log_success "Backup created successfully:"
		list_item "$file_path"
		list_item "Checksum generated: $(cat "${file_path}.sha256")"
		_pg_cleanup_old_backups "$safe_db_name"
	else
		log_error "Failed to create backup"
		rm -f "$file_path"
		return 1
	fi
}

pg_restore_db() {
	check_pg_installed || return 1
	local db_name="$1"
	local backup_file="$2"

	local backup_dir="$KARNEL_DATA/pg_backups"
	if [[ ! -d "$backup_dir" ]]; then
		log_error "No backups directory found: $backup_dir"
		return 1
	fi

	local -a files=()
	while IFS= read -r f; do
		if [[ -n "$f" ]]; then
			files+=("$f")
		fi
	done < <(find "$backup_dir" \( -name "*.backup" -o -name "*.backup.gz" \) -type f 2>/dev/null | sort -r)

	if [[ ${#files[@]} -eq 0 ]]; then
		log_error "No backup files found in $backup_dir"
		return 1
	fi

	if [[ -z "$backup_file" ]]; then
		log_info "Select a backup file to restore:"
		local idx=0
		for f in "${files[@]}"; do
			printf "    ${D_GREEN}%2d.${D_NC} %s\n" $((idx + 1)) "$(basename "$f")"
			((idx++))
		done
		echo
		local pick
		read_input "Select backup file (#)" pick
		if [[ "$pick" =~ ^[0-9]+$ ]] && ((pick >= 1 && pick <= ${#files[@]})); then
			backup_file="${files[$((pick - 1))]}"
		else
			log_error "Invalid selection"
			return 1
		fi
	fi

	if [[ ! -f "$backup_file" ]]; then
		log_error "Backup file not found: $backup_file"
		return 1
	fi

	if [[ -f "${backup_file}.sha256" ]]; then
		log_info "Verifying backup integrity..."
		local current_hash
		current_hash=$(sha256sum "$backup_file" | cut -d' ' -f1)
		local expected_hash
		expected_hash=$(cat "${backup_file}.sha256" 2>/dev/null)
		if [[ "$current_hash" != "$expected_hash" ]]; then
			log_warn "Integrity validation FAILED!"
			log_warn "Current SHA256: $current_hash"
			log_warn "Expected SHA256: $expected_hash"
			local confirm
			read_confirm "Continue restoring anyway?" confirm
			if [[ "$confirm" != "y" ]]; then
				log_error "Restoration aborted by user"
				return 1
			fi
		else
			log_success "Integrity check: OK"
		fi
	else
		log_warn "No SHA256 checksum file found. Integrity check skipped."
	fi

	if [[ -z "$db_name" ]]; then
		read_input "Enter target database name" db_name
	fi

	if [[ -z "$db_name" ]]; then
		log_error "No target database provided"
		return 1
	fi

	if ! pg_detect_data; then
		log_error "PostgreSQL not initialized. Run: karnel pg init"
		return 1
	fi

	if ! psql -lqt | cut -d \| -f 1 | grep -w "$db_name" &>/dev/null; then
		log_info "Target database '$db_name' does not exist. Creating it..."
		if ! createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$db_name" &>/dev/null; then
			log_error "Failed to create target database '$db_name'"
			return 1
		fi
		log_success "Database '$db_name' created"
	fi

	log_info "Restoring backup into '$db_name'..."

	local success=false
	local pg_confirm
	read_confirm "Restore will clean ($db_name) and replace all objects. Continue?" pg_confirm n
	if [[ "$pg_confirm" != "y" ]]; then
		log_info "Restore cancelled"
		return 0
	fi
	if [[ "$backup_file" == *.gz ]]; then
		if loading "Restoring compressed database" _run_restore_cmd "$db_name" "$backup_file"; then
			success=true
		fi
	else
		local pg_log="$KARNEL_CACHE/pg-restore.log"
		if loading "Restoring database" pg_restore -d "$db_name" -c --single-transaction "$backup_file" 2>>"$pg_log"; then
			success=true
		else
			log_warn "pg_restore failed; details in: $pg_log"
		fi
	fi

	if [[ "$success" == "true" ]]; then
		log_success "Database '$db_name' restored successfully"
	else
		log_error "Failed to restore database. Make sure the database is compatible."
		return 1
	fi
}

pg_list_backups() {
	local backup_dir="$KARNEL_DATA/pg_backups"
	separator
	box "Available PostgreSQL Backups"
	separator
	echo
	if [[ ! -d "$backup_dir" ]]; then
		log_info "No backups directory found"
		return 0
	fi

	local -a backups=()
	while IFS= read -r f; do
		if [[ -n "$f" ]]; then
			backups+=("$f")
		fi
	done < <(find "$backup_dir" \( -name "*.backup" -o -name "*.backup.gz" \) -type f 2>/dev/null | sort -r)

	if [[ ${#backups[@]} -eq 0 ]]; then
		log_info "No backup files found."
		separator
		return 0
	fi

	table_start "Database" "Backup File" "Size" "Date" "Integrity"
	for f in "${backups[@]}"; do
		local base=$(basename "$f")
		local db=$(echo "$base" | cut -d'_' -f1)
		local size=$(du -sh "$f" | awk '{print $1}')
		local date_str
		local date_part=$(echo "$base" | grep -oE '[0-9]{8}_[0-9]{6}')
		if [[ -n "$date_part" ]]; then
			date_str="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${date_part:9:2}:${date_part:11:2}:${date_part:13:2}"
		else
			date_str="Unknown"
		fi

		local integrity="OK"
		if [[ -f "${f}.sha256" ]]; then
			local current_hash
		current_hash=$(sha256sum "$f" | cut -d' ' -f1)
			local expected_hash
			expected_hash=$(cat "${f}.sha256" 2>/dev/null)
			if [[ "$current_hash" != "$expected_hash" ]]; then
				integrity="Corrupted"
			fi
		else
			integrity="No checksum"
		fi
		table_row "$db" "$base" "$size" "$date_str" "$integrity"
	done
	table_end
	echo
}

pg_schedule() {
	separator
	box "Schedule Automated PostgreSQL Backups"
	separator
	echo
	check_pg_installed || return 1

	local db_name
	read_input "Enter database name to schedule" db_name
	if [[ -z "$db_name" ]]; then
		log_error "Database name required"
		return 1
	fi

	local interval
	read_select "Select backup frequency" interval "Daily (2:00 AM)" "Weekly (Sundays 2:00 AM)" "Hourly" "Cancel"
	[[ "$interval" == "Cancel" ]] && return 0

	local cron_expr=""
	case "$interval" in
		"Daily (2:00 AM)") cron_expr="0 2 * * *" ;;
		"Weekly (Sundays 2:00 AM)") cron_expr="0 2 * * 0" ;;
		"Hourly") cron_expr="0 * * * *" ;;
	esac

	if [[ -n "$cron_expr" ]]; then
		if ! command -v crontab &>/dev/null; then
			log_warn "crontab command not found. Trying to install cronie..."
			pkg install -y cronie >/dev/null 2>&1 || true
		fi

		local escaped_db; printf -v escaped_db '%q' "$db_name"
		local escaped_path; printf -v escaped_path '%q' "$KARNEL_PATH"
		local pg_log="$KARNEL_CACHE/pg-backup.log"
		local job="$cron_expr PATH=\"$PREFIX/bin:/usr/bin:/bin\" PREFIX=\"$PREFIX\" KARNEL_PATH=$escaped_path $escaped_path/bin/karnel pg backup $escaped_db >>\"$pg_log\" 2>&1"
		local tmpcron
		tmpcron="$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-pg.XXXXXX")" || {
			log_error "Failed to schedule backup for database '$db_name'"
			return 1
		}
		{
			crontab -l 2>/dev/null | grep -vF "karnel pg backup $escaped_db"
			echo "$job"
		} >"$tmpcron"
		if crontab "$tmpcron"; then
			log_success "Backup scheduled successfully ($interval) for database '$db_name'!"
			list_item "Ensure cron daemon is running (run: 'crond')"
		else
			log_error "Failed to schedule backup for database '$db_name'"
			rm -f "$tmpcron"
			return 1
		fi
		rm -f "$tmpcron"
	fi
	echo
}
