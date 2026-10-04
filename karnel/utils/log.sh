#!/usr/bin/env bash

import "@/utils/colors"

# ===== LOG FUNCTIONS =====

log_info() {
	echo -e "    ${CYAN}➜${D_CYAN} $*${D_NC}"
}

log_success() {
	echo -e "    ${GREEN}✔${D_GREEN} $*${D_NC}"
}

log_warn() {
	echo -e "    ${YELLOW}⚠${D_YELLOW} $*${D_NC}"
}

log_error() {
	echo -e "    ${RED}✖${D_RED} $*${D_NC}" >&2
}

log_debug() {
	if [[ "${KARNEL_DEBUG:-0}" == "1" ]]; then
		echo -e "    ${PURPLE}⚙${D_PURPLE} [DEBUG] $*${D_NC}"
	fi
}

list_item() {
	echo -e "    ${GRAY}•${D_NC} $*"
}

list_item_check() {
	local status="$1"
	local text="$2"

	case "$status" in
	"done" | "success")
		echo -e "    ${GREEN}✔${D_NC} $text"
		;;
	"pending")
		echo -e "    ${YELLOW}⏳${D_NC} $text"
		;;
	"error" | "fail")
		echo -e "    ${RED}✖${D_NC} $text"
		;;
	*)
		echo -e "    ${GRAY}•${D_NC} $text"
		;;
	esac
}

# ===== SEPARATOR FUNCTIONS =====

separator() {
	local cols
	cols=$(tput cols 2>/dev/null || echo 80)
	local line
	line=$(printf "%${cols}s")
	echo -e "${GRAY}${line// /─}${NC}"
}

separator_section() {
	local title="$1"
	local cols
	cols=$(tput cols 2>/dev/null || echo 80)
	local padding=$(( (cols - ${#title} - 2) / 2 ))
	local line
	line=$(printf "%${padding}s")

	echo -e "${GRAY}${line// /─} ${D_CYAN}${title}${GRAY} ${line// /─}${NC}"
}

# ===== BOX FUNCTIONS =====

# Draw a box around the given text
box() {
	local text="$1"
	local len=${#text}
	local line
	line=$(printf "%$((len + 2))s")

	echo -e "${GRAY}╭${line// /─}╮${NC}"
	echo -e "${GRAY}│${D_CYAN} $text ${GRAY}│${NC}"
	echo -e "${GRAY}╰${line// /─}╯${NC}"
}

# ===== TABLE FUNCTIONS =====

# ===== INTERNAL TABLE STATE =====
TABLE_HEADERS=()
TABLE_ROWS=()
TABLE_WIDTHS=()

# ===== START TABLE =====
table_start() {
	TABLE_HEADERS=("$@")
	TABLE_ROWS=()
}

# ===== ADD ROW =====
# Uso simple: table_row "valor1" "valor2" "valor3"
# Por defecto: col 1 → D_GREEN, col 2 → D_CYAN, resto → sin color
# También acepta colores custom: table_row "${RED}valor${NC}" ...
table_row() {
	local -a colored=()
	local i=0
	for field in "$@"; do
		# Solo aplicar color por defecto si el campo no contiene ya un escape ANSI
		if [[ "$field" != *$'\x1b['* ]]; then
			case $i in
			0) colored+=("${D_GREEN}${field}${NC}") ;;
			1) colored+=("${D_CYAN}${field}${NC}") ;;
			*) colored+=("${D_NC}${field}${NC}") ;;
			esac
		else
			colored+=("$field")
		fi
		((i++))
	done
	local IFS=$'\x1F'
	TABLE_ROWS+=("${colored[*]}")
}

# ===== STRIP ANSI =====
# Elimina códigos de escape ANSI para medir la longitud visual real
strip_ansi() {
	echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# ===== CALCULATE COLUMN WIDTHS =====
table_calc_widths() {
	local cols=${#TABLE_HEADERS[@]}

	for ((i = 0; i < cols; i++)); do
		TABLE_WIDTHS[$i]=${#TABLE_HEADERS[$i]}
	done

	for row in "${TABLE_ROWS[@]}"; do
		IFS=$'\x1F' read -r -a fields <<<"$row"
		for ((i = 0; i < cols; i++)); do
			local visual
			visual=$(strip_ansi "${fields[$i]}")
			local len=${#visual}
			((len > TABLE_WIDTHS[$i])) && TABLE_WIDTHS[$i]=$len
		done
	done
}

# ===== BORDER HELPERS =====
# Genera una línea horizontal con los caracteres correctos según posición
# $1: char izquierdo, $2: char relleno, $3: char separador, $4: char derecho
table_border() {
	local left="$1" fill="$2" sep="$3" right="$4"
	echo -ne "${GRAY}${left}"
	local last=$((${#TABLE_WIDTHS[@]} - 1))
	for i in "${!TABLE_WIDTHS[@]}"; do
		local w="${TABLE_WIDTHS[$i]}"
		local line
		line=$(printf "%$((w + 2))s")
		echo -ne "${line// /${fill}}"
		if ((i < last)); then
			echo -ne "${sep}"
		fi
	done
	echo -e "${right}${NC}"
}

# ===== RENDER TABLE =====
table_end() {
	table_calc_widths

	local cols=${#TABLE_HEADERS[@]}

	# Top border:    ┌───┬───┐
	table_border "┌" "─" "┬" "┐"

	# Headers (D_RED por defecto)
	echo -ne "${GRAY}│${NC}"
	for ((i = 0; i < cols; i++)); do
		printf " ${D_RED}%-${TABLE_WIDTHS[$i]}s ${GRAY}│${NC}" "${TABLE_HEADERS[$i]}"
	done
	echo

	# Middle border: ├───┼───┤
	table_border "├" "─" "┼" "┤"

	# Rows
	for row in "${TABLE_ROWS[@]}"; do
		IFS=$'\x1F' read -r -a fields <<<"$row"

		echo -ne "${GRAY}│${NC}"
		for ((i = 0; i < cols; i++)); do
			local display="${fields[$i]}"
			local visual
			visual=$(strip_ansi "$display")

			local pad=$((TABLE_WIDTHS[$i] - ${#visual}))
			local spaces
			printf -v spaces "%${pad}s" ""

			printf " %b%s ${GRAY}│${NC}" "$display" "$spaces"
		done
		echo
	done

	# Bottom border: └───┴───┘
	table_border "└" "─" "┴" "┘"
}

# ===== READ FUNCTIONS =====
# El segundo argumento es el nombre de la variable donde se guarda el resultado.

# --- Texto simple ---
# Uso: read_input "Prompt" VAR_NAME
read_input() {
	local prompt="$1"
	local var="$2"
	local _val

	if [[ ! -t 0 ]]; then
		read -r "$var" <<<""
		return 1
	fi

	echo -e -n "    ${GRAY}┌─${D_CYAN} ${prompt} ${NC}\n" >&2
	echo -e -n "    ${GRAY}└─${D_CYAN}▶ ${D_NC}" >&2
	read -r _val
	read -r "$var" <<<"$_val"
}

# --- Entrada censurada (contraseñas, tokens, API keys) ---
# Lee carácter por carácter y muestra ● para cada uno.
# Uso: read_secret "Prompt" VAR_NAME
read_secret() {
	local prompt="$1"
	local var="$2"
	local _val=""
	local char

	echo -e -n "    ${GRAY}┌─${D_CYAN} ${prompt} ${NC}\n" >&2
	echo -e -n "    ${GRAY}│${D_DIM} (input will be hidden)${D_NC}\n" >&2
	echo -e -n "    ${GRAY}└─${D_CYAN}▶ ${D_NC}" >&2

	local old_stty
	old_stty=$(stty -g 2>/dev/null)
	trap 'stty "$old_stty" 2>/dev/null; echo >&2; return 1' INT TERM
	stty -echo -icanon min 1 time 0 2>/dev/null

	while true; do
		char=$(dd bs=1 count=1 2>/dev/null)
		if [[ "$char" == $'\n' ]] || [[ "$char" == $'\r' ]] || [[ -z "$char" ]]; then
			break
		fi
		if [[ "$char" == $'\177' ]] || [[ "$char" == $'\b' ]]; then
			if [[ -n "$_val" ]]; then
				_val="${_val%?}"
				echo -ne "\b \b" >&2
			fi
		else
			_val+="$char"
			echo -ne "●" >&2
		fi
	done

	stty "$old_stty" 2>/dev/null
	trap - INT TERM
	echo >&2
	read -r "$var" <<<"$_val"
}

# --- Confirmación s/n ---
# Uso: read_confirm "¿Continuar?" VAR_NAME [AUTO_ANSWER]
# Retorna 0 si sí, 1 si no. VAR_NAME recibe "y" o "n"
#
# AUTO_ANSWER ("y" por omisión) es lo que se responde cuando --auto activa el
# modo no interactivo. Las acciones destructivas deben pasar "n" explícitamente
# para que --auto nunca las ejecute sin que el usuario lo pida.
read_confirm() {
	local prompt="$1"
	local var="$2"
	local auto_answer="${3:-y}"
	local _val

	if [[ "${KARNEL_AUTO:-0}" == "1" ]]; then
		read -r "$var" <<<"$auto_answer"
		[[ "$auto_answer" == "y" ]] && return 0 || return 1
	fi

	if [[ ! -t 0 ]]; then
		read -r "$var" <<<"n"
		return 1
	fi

	while true; do
		echo -e -n "    ${GRAY}┌─${D_YELLOW} ${prompt} ${GRAY}[${D_GREEN}y${GRAY}/${D_RED}n${GRAY}]${D_NC}\n" >&2
		echo -e -n "    ${GRAY}└─${D_YELLOW}▶ ${D_NC}" >&2
		read -rn1 _val
		echo >&2
		case "${_val,,}" in
		y)
			read -r "$var" <<<"y"
			return 0
			;;
		n)
			read -r "$var" <<<"n"
			return 1
			;;
		*) echo -e "    ${RED}✖${D_NC} Reply ${D_GREEN}y${D_NC} o ${D_RED}n${D_NC}" >&2 ;;
		esac
	done
}

# --- Confirmación con default ---
# default="y" -> [Y/n]  |  default="n" -> [y/N]
# Retorna 0 si sí, 1 si no. VAR_NAME recibe "y" o "n"
#
# Con --auto se responde el propio default (nunca "y" forzado), de modo que
# una opción destructiva marcada como default "n" no se ejecute sola. Un
# cuarto argumento permite forzar otra respuesta auto puntual.
read_confirm_default() {
	local prompt="$1"
	local default="$2"
	local var="$3"
	local auto_answer="${4:-$2}"
	local _val

	if [[ "${KARNEL_AUTO:-0}" == "1" ]]; then
		read -r "$var" <<<"$auto_answer"
		[[ "$auto_answer" == "y" ]] && return 0 || return 1
	fi

	if [[ ! -t 0 ]]; then
		read -r "$var" <<<"$default"
		[[ "$default" == "y" ]] && return 0 || return 1
	fi

	local show_default
	if [[ "$default" == "y" ]]; then
		show_default="${D_GREEN}Y${GRAY}/${D_RED}n${GRAY}"
	else
		show_default="${D_GREEN}y${GRAY}/${D_RED}N${GRAY}"
	fi

	while true; do
		echo -e -n "    ${GRAY}┌─${D_YELLOW} ${prompt} ${GRAY}[${show_default}${GRAY}]${D_NC}\n" >&2
		echo -e -n "    ${GRAY}└─${D_YELLOW}▶ ${D_NC}" >&2
		read -rn1 _val
		echo >&2
		if [[ -z "$_val" ]]; then
			_val="$default"
		fi
		case "${_val,,}" in
		y)
			read -r "$var" <<<"y"
			return 0
			;;
		n)
			read -r "$var" <<<"n"
			return 1
			;;
		*) echo -e "    ${RED}✖${D_NC} Reply ${D_GREEN}y${D_NC} o ${D_RED}n${D_NC}" >&2 ;;
		esac
	done
}

# --- Selección de opciones ---
# Uso: read_select "Prompt" VAR_NAME "Opción1" "Opción2" ...
# VAR_NAME recibe el texto de la opción elegida
read_select() {
	local prompt="$1"
	local var="$2"
	shift 2
	local -a options=("$@")

	# Non-interactive mode: a specific --<tool> was requested, so auto-pick
	# the recommended (first) option instead of prompting. This also covers
	# piped/non-TTY input. Tools can still override via KARNEL_INSTALL_METHOD.
	local _auto="${KARNEL_INSTALL_METHOD:-0}"
	if [[ -n "${KARNEL_NONINTERACTIVE:-}" ]] || [[ ! -t 0 ]]; then
		if [[ "$_auto" != "0" ]] && (( _auto < ${#options[@]} )); then
			selected="$_auto"
		else
			selected=0
		fi
		read -r "$var" <<<"${options[$selected]}"
		echo -e "    ${GRAY}└─${D_CYAN}▶ ${D_NC}${options[$selected]}${D_NC}" >&2
		return 0
	fi

	local selected=0
	local total=${#options[@]}
	local cols
	cols=$(tput cols 2>/dev/null || echo 80)
	local margin=6
	local max_width=$((cols - margin))

	_render_select() {
		echo -e "    ${GRAY}┌─${D_CYAN} ${prompt}${NC}" >&2
		for ((i = 0; i < total; i++)); do
			local text="${options[$i]}"
			if (( ${#text} > max_width )); then
				text="${text:0:$((max_width - 3))}..."
			fi
			if ((i == selected)); then
				echo -e "    ${GRAY}│  ${D_CYAN}▶ ${WHITE}${text}${D_NC}" >&2
			else
				echo -e "    ${GRAY}│    ${GRAY}${text}${D_NC}" >&2
			fi
		done
		echo -e -n "    ${GRAY}└─${D_NC} ${GRAY}↑↓ move  Enter confirm${D_NC}" >&2
	}

	local lines=$((total + 1))

	tput civis 2>/dev/null || true
	_render_select

	while true; do
		IFS= read -rsn1 key
		if [[ "$key" == $'\x1b' ]]; then
			read -rsn2 -t 0.1 rest
			key="${key}${rest}"
		fi

		case "$key" in
		$'\x1b[A' | k) ((selected > 0)) && ((selected--)) ;;
		$'\x1b[B' | j) ((selected < total - 1)) && ((selected++)) ;;
		'') break ;;
		esac

		echo -en "\r\033[${lines}A\033[J" >&2
		_render_select
	done

	echo >&2
	tput cnorm 2>/dev/null || true

	read -r "$var" <<<"${options[$selected]}"
	echo -e "    ${GRAY}└─${D_CYAN}▶ ${D_NC}${options[$selected]}${D_NC}" >&2
}

# ===== LOADING SPINNER =====

loading() {
	local message="$1"
	shift

	local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
	local delay=0.08
	local tmpfile
	local _ktmpdir="${KARNEL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/karnel}"
	mkdir -p "$_ktmpdir" 2>/dev/null || _ktmpdir="${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}"
	tmpfile="$(mktemp "$_ktmpdir/karnel.XXXXXX" 2>/dev/null)" || tmpfile="$(mktemp 2>/dev/null)"
	local cmd_pid=""

	trap 'kill "$cmd_pid" 2>/dev/null; rm -f "$tmpfile"; return 1' INT TERM

	printf "    ${CYAN}⠋${D_CYAN} %s${NC}" "$message"

	mkdir -p "$KARNEL_CACHE"

	"$@" >"$tmpfile" 2>&1 &
	cmd_pid=$!

	local frame_idx=0
	while kill -0 "$cmd_pid" 2>/dev/null; do
		printf "\r    ${CYAN}%s${D_CYAN} %s${NC}" "${frames[$frame_idx]}" "$message"
		frame_idx=$(( (frame_idx + 1) % ${#frames[@]} ))
		sleep "$delay"
	done

	wait "$cmd_pid" 2>/dev/null
	local exit_code=$?
	trap - INT TERM

	if [[ $exit_code -eq 0 ]]; then
		printf "\r    ${GREEN}✔${D_GREEN} %s${NC}\n" "$message"
		[[ -s "$tmpfile" ]] && cat "$tmpfile"
	elif [[ $exit_code -eq 2 ]]; then
		printf "\r    ${CYAN}➜${D_CYAN} %s${NC}\n" "$message"
		[[ -s "$tmpfile" ]] && cat "$tmpfile"
	else
		printf "\r    ${RED}✖${D_RED} %s${NC}\n" "$message"
		cat "$tmpfile"
	fi

	rm -f "$tmpfile"
	return $exit_code
}

# ===== PROGRESS BAR =====

_progress_current=0
_progress_total=0
_progress_width=50

progress_bar() {
	local current=$1
	local total=$2
	local width=${3:-50}
	((total == 0)) && total=1
	_progress_current=$current
	_progress_total=$total
	_progress_width=$width
	local percentage=$((current * 100 / total))
	local filled=$((current * width / total))
	local empty=$((width - filled))

	local bar=""
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	for ((i = 0; i < empty; i++)); do bar+="░"; done

	printf "\r    ${D_CYAN}[${D_NC}${D_GREEN}%s${D_NC}${D_CYAN}]${D_NC} %3d%%" "$bar" "$percentage"
}

progress_start() {
	local total=$1
	local message="${2:-Progress}"
	_progress_current=0
	_progress_filled=0
	_progress_total=$total
	_progress_width=50
	printf "    ${D_CYAN}%s${D_NC}" "$message"
	printf "\n    ${D_CYAN}[${D_NC}"
	for ((i = 0; i < _progress_width; i++)); do
		printf "${D_NC}░${D_CYAN}"
	done
	printf "${D_CYAN}]${D_NC} 0%%\n"
	printf "\033[1A"
	progress_bar 0 "$total"
}

progress_update() {
	local current=$1
	local total=$2
	local width="${_progress_width:-50}"
	((total == 0)) && total=1
	local target_filled=$((current * width / total))

	local prev="${_progress_filled:-0}"
	[[ "$target_filled" -lt "$prev" ]] && prev=0

	local anim i j bar pct
	for ((i = prev + 1; i <= target_filled; i++)); do
		bar=""
		for ((j = 0; j < i; j++)); do bar="${bar}█"; done
		for ((j = i; j < width; j++)); do bar="${bar}░"; done
		pct=$((i * 100 / width))
		printf "\r    ${D_CYAN}[${D_NC}${D_GREEN}%s${D_NC}${D_CYAN}]${D_NC} %3d%%" "$bar" "$pct"
		sleep 0.003 2>/dev/null || true
	done

	_progress_filled="$target_filled"
}

progress_done() {
	local total=$1
	progress_update "$total" "$total"
	printf "\n    ${GREEN}✔${D_NC} Complete\n"
}

# ===== BADGE FUNCTIONS =====

badge() {
  local text="$1"
  local color="${2:-D_CYAN}"
  echo -e "${!color}[ $text ]${NC}"
}

# ===== TIP =====

log_tip() {
	echo -e "    ${PURPLE}💡${D_PURPLE} $*${D_NC}"
}
