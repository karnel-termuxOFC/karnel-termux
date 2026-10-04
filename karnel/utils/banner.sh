#!/usr/bin/env bash
# Note: deliberately NOT using set -e here — it leaks errexit to the parent
# shell, causing non-existent commands to exit zsh with code 127.

ESC=$(printf '\033')
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
NC="${ESC}[0m"

# The banner is sourced directly from shell startup files, so the CLI has not
# computed KARNEL_VERSION yet. Resolve it once from package.json.
if [[ -z "${KARNEL_VERSION:-}" ]]; then
  _karnel_banner_src=""
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _karnel_banner_src="${BASH_SOURCE[0]}"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # `${(%):-%x}` is zsh syntax. It sits behind eval so bash can parse this
    # file at all; it is only ever expanded while ZSH_VERSION is set, and a
    # failed expansion just falls through to the default version below.
    _karnel_banner_src=$(eval 'printf %s "${(%):-%x}"' 2>/dev/null || true)
  fi
  if [[ -n "$_karnel_banner_src" ]]; then
    # banner.sh lives at karnel/utils/, package.json is two levels up.
    _karnel_pkg="$(dirname "$_karnel_banner_src")/../../package.json"
    if [[ -f "$_karnel_pkg" ]]; then
      KARNEL_VERSION=$(grep -m1 '"version"' "$_karnel_pkg" 2>/dev/null |
        sed -E 's/.*"version": *"([^"]+)".*/\1/')
    fi
    unset _karnel_pkg
  fi
  unset _karnel_banner_src
fi
: "${KARNEL_VERSION:=4.x}"

# Column width, guarding against an unset/invalid COLUMNS or a missing tput.
_banner_cols() {
  local cols="${COLUMNS:-}"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=$(tput cols 2>/dev/null || true)
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  printf '%s' "$cols"
}

# Every colour/index table below is associative. Bash arrays are 0-indexed while
# zsh arrays are 1-indexed, so indexed arrays would shift every colour by one
# (and index 0 would be empty) when the banner is sourced from .zshrc.

# TrueColor helper (original gradient: red → purple → blue → black)
tc() { printf '%s[38;2;%d;%d;%dm' "$ESC" "$1" "$2" "$3"; }

WHITE=$(tc 255 255 255)
GRAY="${ESC}[0;90m"

# TP gradient: cyan → blue → purple → magenta (muted, original style)
declare -A TP=()
for i in $(seq 0 15); do
  if   (( i < 4 )); then
    r=$(( 0 + i * 16 )); g=$(( 200 + i * 14 )); b=$(( 255 - i * 10 ))
  elif (( i < 8 )); then
    r=$(( 48 + (i-4) * 8 )); g=$(( 255 - (i-4) * 32 )); b=$(( 215 - (i-4) * 25 ))
  elif (( i < 12 )); then
    r=$(( 80 + (i-8) * 30 )); g=$(( 127 - (i-8) * 25 )); b=$(( 115 - (i-8) * 20 ))
  else
    r=$(( 200 + (i-12) * 14 )); g=$(( 27 + (i-12) * 5 )); b=$(( 35 + (i-12) * 20 ))
  fi
  (( r > 255 )) && r=255; (( g > 255 )) && g=255; (( b > 255 )) && b=255
  (( r < 0 )) && r=0; (( g < 0 )) && g=0; (( b < 0 )) && b=0
  TP[$i]="$(tc "$r" "$g" "$b")"
done
unset i r g b

CYAN="${TP[0]}"
BLUE="${TP[4]}"
PURP="${TP[8]}"
MAG="${TP[12]}"
PINK=$(tc 255 80 140)
RED=$(tc 220 50 50)
RUBY=$(tc 220 50 60)
OBSIDIAN=$(tc 140 90 200)
GREEN1=$(tc 80 220 80)
GREEN2=$(tc 60 200 120)
C07="${TP[7]}"
C01="${TP[1]}"
C03="${TP[3]}"
C05="${TP[5]}"
C09="${TP[9]}"
C11="${TP[11]}"
C13="${TP[13]}"

# RK gradient: red → purple → blue → black (original)
declare -A RK=()
for _i in $(seq 0 15); do
  if (( _i < 6 )); then
    _r=$(( 255 - _i * 10 ))
    _g=$(( 40 + _i * 22 ))
    _b=$(( 40 + _i * 28 ))
  elif (( _i < 11 )); then
    _r=$(( 195 - (_i-6) * 30 ))
    _g=$(( 172 - (_i-6) * 28 ))
    _b=$(( 208 - (_i-6) * 15 ))
  else
    _r=$(( 45 - (_i-11) * 8 ))
    _g=$(( 32 - (_i-11) * 6 ))
    _b=$(( 133 - (_i-11) * 26 ))
  fi
  (( _r < 0 )) && _r=0; (( _g < 0 )) && _g=0; (( _b < 0 )) && _b=0
  RK[$_i]="$(tc "$_r" "$_g" "$_b")"
done
unset _i _r _g _b

# Metallic shine (pure gold → bright white gradient)
M_SHINE=$(tc 255 215 0)
M_GOLD=$(tc 255 200 50)
M_SILVER=$(tc 220 220 255)

_ansi_len() {
  printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' '
}

_center() {
  local text="$1" width="$2"
  local vis; vis=$(_ansi_len "$text")
  local total=$(( width - vis ))
  # A line wider than the box would otherwise pass a negative width to printf,
  # which silently prints abs(width) extra spaces and pushes the border out.
  (( total < 0 )) && total=0
  local left=$(( total / 2 ))
  local right=$(( total - left ))
  printf '%*s' "$left" ''
  printf '%s' "$text"
  printf '%*s' "$right" ''
}

_repeat() {
  local ch="$1" n="$2" out="" _z
  for ((_z=0; _z<n; _z++)); do out+="$ch"; done
  printf '%s' "$out"
}



# ================================================================
# Figlet-generated text with red-black gradient
# ================================================================
FIGLET_TEXT=""
TERMUX_FIGLET_TEXT=""
declare -A FIGLET_LINES=()
declare -A TERMUX_FIGLET_LINES=()
if command -v figlet &>/dev/null; then
  FIGLET_TEXT=$(figlet -f big "KARNEL" 2>/dev/null || true)
  TERMUX_FIGLET_TEXT=$(figlet -f big "TERMUX" 2>/dev/null || true)
fi
if [[ -n "$FIGLET_TEXT" ]]; then
  # `<<<` appends a newline, so drop trailing newlines first or the split below
  # yields a phantom empty line (which renders as a blank row in the box).
  while [[ "$FIGLET_TEXT" == *$'\n' ]]; do FIGLET_TEXT="${FIGLET_TEXT%$'\n'}"; done
  _fl_i=0
  while IFS= read -r _fl; do
    FIGLET_LINES[$_fl_i]="$_fl"
    _fl_i=$((_fl_i + 1))
  done <<< "$FIGLET_TEXT"
  unset _fl_i
fi
if [[ -n "$TERMUX_FIGLET_TEXT" ]]; then
  while [[ "$TERMUX_FIGLET_TEXT" == *$'\n' ]]; do TERMUX_FIGLET_TEXT="${TERMUX_FIGLET_TEXT%$'\n'}"; done
  _tl_i=0
  while IFS= read -r _tl; do
    TERMUX_FIGLET_LINES[$_tl_i]="$_tl"
    _tl_i=$((_tl_i + 1))
  done <<< "$TERMUX_FIGLET_TEXT"
  unset _tl_i
fi
unset _fl _tl

# ================================================================
# Metallic shine — passes over the big figlet letters only
# ================================================================
_metallic_apply() {
  local _text="$1" _base_color="$2" _scan="${3:-}"
  local _trimmed="${_text#"${_text%%[! ]*}"}"
  _trimmed="${_trimmed%"${_trimmed##*[! ]}"}"
  local _text_len=${#_trimmed}

  if (( _text_len < 4 )); then
    echo "${_base_color}${_text}${NC}"
    return
  fi

  local _lead="${_text%%[! ]*}"
  local _lead_len=${#_lead}
  local _center
  if [[ -n "$_scan" ]]; then
    _center=$(( _lead_len + _scan ))
  else
    _center=$(( _lead_len + _text_len / 2 ))
  fi

  local _core_r=$(( _text_len / 12 + 1 ))
  local _halo_r=$(( _text_len / 7 + 2 ))
  local _glow_r=$(( _text_len / 3 + 3 ))

  local _out="" _i _char
  for (( _i = 0; _i < ${#_text}; _i++ )); do
    _char="${_text:_i:1}"
    if [[ "$_char" == " " ]]; then
      _out+=" "
    else
      local _dist=$(( _i > _center ? _i - _center : _center - _i ))
      if (( _dist < _core_r )); then
        _out+="${BOLD}${WHITE}${_char}"
      elif (( _dist < _halo_r )); then
        _out+="${BOLD}${M_GOLD}${_char}"
      elif (( _dist < _glow_r )); then
        _out+="${M_SHINE}${_char}"
      else
        _out+="${_base_color}${_char}"
      fi
    fi
  done
  _out+="${NC}"
  echo "$_out"
}



# ================================================================
# Frame line (top / bottom) — pure TP gradient, no shine
# ================================================================
_render_frame_line() {
  local _which="$1"
  local cols; cols=$(_banner_cols)
  local W=$(( cols > 72 ? 68 : cols - 6 ))
  (( W < 40 )) && W=40
  local GAP_L=$(( (cols - W - 2) / 2 ))
  (( GAP_L < 0 )) && GAP_L=0
  local GAP_R=$(( cols - W - 2 - GAP_L ))
  (( GAP_R < 0 )) && GAP_R=0
  local pad_l; pad_l=$(printf '%*s' "$GAP_L" '')
  local pad_r; pad_r=$(printf '%*s' "$GAP_R" '')

  local p1 p2 p3
  p1=$(( W / 4 )); p2=$(( W / 2 )); p3=$(( 3 * W / 4 ))
  local frame="" i m_color
  for (( i = 0; i < W; i++ )); do
    local c_idx=$(( i * 16 / W ))
    (( c_idx > 15 )) && c_idx=15
    m_color="${TP[$c_idx]}"
    if (( i == 1 || i == W-2 )); then
      frame+="${m_color}╌${NC}"
    elif (( i == p1 || i == p2 || i == p3 )); then
      if [[ "$_which" == "top" ]]; then
        frame+="${m_color}┬${NC}"
      else
        frame+="${m_color}┴${NC}"
      fi
    else
      frame+="${m_color}─${NC}"
    fi
  done

  if [[ "$_which" == "top" ]]; then
    echo "${pad_l}${WHITE}╭${NC}${frame}${WHITE}╮${NC}${pad_r}"
  else
    echo "${pad_l}${WHITE}╰${NC}${frame}${WHITE}╯${NC}${pad_r}"
  fi
}

# ================================================================
# Panel
# ================================================================


# ================================================================
# Render
# ================================================================
_render_top() {
  local cols; cols=$(_banner_cols)
  local W=$(( cols > 72 ? 68 : cols - 6 ))
  (( W < 40 )) && W=40
  local GAP_L=$(( (cols - W - 2) / 2 ))
  (( GAP_L < 0 )) && GAP_L=0
  local GAP_R=$(( cols - W - 2 - GAP_L ))
  (( GAP_R < 0 )) && GAP_R=0
  local pad_l; pad_l=$(printf '%*s' "$GAP_L" '')
  local pad_r; pad_r=$(printf '%*s' "$GAP_R" '')
  local l_border="${TP[0]}" r_border="${TP[15]}"
  local sp_line; sp_line=$(printf '%*s' "$W" '')

  _render_frame_line "top"
  local hdr="${TP[1]}┄${NC}${TP[1]}┄${NC} ${M_SHINE}◈${NC} ${BOLD}${WHITE}KARNEL${NC} ${WHITE}✦${NC} ${BOLD}${WHITE}SYSTEMS${NC} ${M_SHINE}◈${NC} ${TP[1]}┄${NC}${TP[1]}┄${NC}"
  echo "${pad_l}${l_border}│${NC}$(_center "$hdr" "$W")${r_border}│${NC}${pad_r}"
  echo "${pad_l}${l_border}│${NC}${sp_line}${r_border}│${NC}${pad_r}"
}

_render_text_logo() {
  local cols; cols=$(_banner_cols)
  local W=$(( cols > 72 ? 68 : cols - 6 ))
  (( W < 40 )) && W=40
  local GAP_L=$(( (cols - W - 2) / 2 ))
  (( GAP_L < 0 )) && GAP_L=0
  local GAP_R=$(( cols - W - 2 - GAP_L ))
  (( GAP_R < 0 )) && GAP_R=0
  local pad_l; pad_l=$(printf '%*s' "$GAP_L" '')
  local pad_r; pad_r=$(printf '%*s' "$GAP_R" '')
  local title="KARNEL   TERMUX"
  local ver_line="v${KARNEL_VERSION}"
  local subtitle="by israel marques"
  local sp_line; sp_line=$(printf '%*s' "$W" '')
  # `tr ' ' '─'` maps byte-wise and produced invalid UTF-8 here, and used W+2
  # cells where the box sides are W — both rendered as mojibake/overrun.
  local edge; edge=$(_repeat "─" "$W")
  echo "${pad_l}${TP[0]}╭${edge}╮${NC}${pad_r}"
  echo "${pad_l}${TP[0]}│${NC}${sp_line}${TP[15]}│${NC}${pad_r}"
  echo "${pad_l}${TP[0]}│${NC}$(_center "${TP[7]}${title}${NC}" "$W")${TP[15]}│${NC}${pad_r}"
  echo "${pad_l}${TP[0]}│${NC}${sp_line}${TP[15]}│${NC}${pad_r}"
  echo "${pad_l}${TP[0]}│${NC}$(_center "${GRAY}${ver_line}${NC}" "$W")${TP[15]}│${NC}${pad_r}"
  echo "${pad_l}${TP[0]}│${NC}$(_center "${DIM}${subtitle}${NC}" "$W")${TP[15]}│${NC}${pad_r}"
  echo "${pad_l}${TP[0]}╰${edge}╯${NC}${pad_r}"
}

_render_figlet() {
  local _anim_off="${1:-0}" _slow="${2:-}"
  local cols; cols=$(_banner_cols)
  local W=$(( cols > 72 ? 68 : cols - 6 ))
  (( W < 40 )) && W=40
  local GAP_L=$(( (cols - W - 2) / 2 ))
  (( GAP_L < 0 )) && GAP_L=0
  local GAP_R=$(( cols - W - 2 - GAP_L ))
  (( GAP_R < 0 )) && GAP_R=0
  local pad_l; pad_l=$(printf '%*s' "$GAP_L" '')
  local pad_r; pad_r=$(printf '%*s' "$GAP_R" '')
  local l_border="${TP[0]}" r_border="${TP[15]}"

  local num_fl=${#FIGLET_LINES[@]} num_tl=${#TERMUX_FIGLET_LINES[@]}

  if (( num_fl == 0 && num_tl == 0 )); then
    _render_text_logo
    return
  fi
  local _fi _ti _line _ci _colored _scan2 _fig_w=0 _fl2 _total_fig_lines=$(( num_fl + num_tl ))
  for _fl2 in "${FIGLET_LINES[@]}"; do local _tl2=${#_fl2}; (( _tl2 > _fig_w )) && _fig_w=$_tl2; done
  local _step=$(( (_fig_w + 16) * 1 / (_total_fig_lines > 1 ? _total_fig_lines - 1 : 1) ))
  (( _step < 1 )) && _step=1
  for (( _fi = 0; _fi < num_fl; _fi++ )); do
    _line="${FIGLET_LINES[$_fi]}"
    _ci=$(( _fi * 16 / (num_fl > 1 ? num_fl : 1) ))
    (( _ci > 15 )) && _ci=15
    _scan2=$(( -8 + _anim_off + _fi * _step ))
    _colored=$(_metallic_apply "$_line" "${RK[$_ci]}" "$_scan2")
    echo "${pad_l}${l_border}│${NC}$( _center "$_colored" "$W" )${r_border}│${NC}${pad_r}"
    [[ -n "$_slow" ]] && sleep 0.2
  done
  for (( _ti = 0; _ti < num_tl; _ti++ )); do
    _line="${TERMUX_FIGLET_LINES[$_ti]}"
    _ci=$(( _ti * 16 / (num_tl > 1 ? num_tl : 1) ))
    (( _ci > 15 )) && _ci=15
    _scan2=$(( -8 + _anim_off + (_fi + _ti) * _step ))
    _colored=$(_metallic_apply "$_line" "${RK[$_ci]}" "$_scan2")
    echo "${pad_l}${l_border}│${NC}$( _center "$_colored" "$W" )${r_border}│${NC}${pad_r}"
    [[ -n "$_slow" ]] && sleep 0.2
  done
}

_render_bottom() {
  local cols; cols=$(_banner_cols)
  local W=$(( cols > 72 ? 68 : cols - 6 ))
  (( W < 40 )) && W=40
  local GAP_L=$(( (cols - W - 2) / 2 ))
  (( GAP_L < 0 )) && GAP_L=0
  local GAP_R=$(( cols - W - 2 - GAP_L ))
  (( GAP_R < 0 )) && GAP_R=0
  local pad_l; pad_l=$(printf '%*s' "$GAP_L" '')
  local pad_r; pad_r=$(printf '%*s' "$GAP_R" '')
  local l_border="${TP[0]}" r_border="${TP[15]}"
  local sp_line; sp_line=$(printf '%*s' "$W" '')

  local div_total=$(( W - 2 ))
  local div_l=$(( (div_total - 3) / 2 ))
  local div_r=$(( div_total - 3 - div_l ))
  local dash_l="" dash_r="" j
  for (( j = 0; j < div_l; j++ )); do
    local m=$(( j % 4 ))
    if (( m == 0 )); then dash_l+="─"
    elif (( m == 1 )); then dash_l+="┄"
    elif (( m == 2 )); then dash_l+="·"
    else dash_l+="─"; fi
  done
  for (( j = 0; j < div_r; j++ )); do
    local m=$(( j % 4 ))
    if (( m == 0 )); then dash_r+="─"
    elif (( m == 1 )); then dash_r+="┄"
    elif (( m == 2 )); then dash_r+="·"
    else dash_r+="─"; fi
  done
  local div_line="${DIM}${dash_l}${NC}${TP[3]}◈${NC}${DIM}${dash_r}${NC}"
  echo "${pad_l}${l_border}│${NC}$(_center "$div_line" "$W")${r_border}│${NC}${pad_r}"

  local gem_line="${M_SHINE}◈${NC} ${BOLD}${RUBY}Dev${NC} ${WHITE}${BOLD}&${NC} ${BOLD}${OBSIDIAN}mobile${NC} ${M_SHINE}◈${NC}"
  echo "${pad_l}${l_border}│${NC}$(_center "$gem_line" "$W")${r_border}│${NC}${pad_r}"
  echo "${pad_l}${l_border}│${NC}$(_center "${GREEN2}${BOLD}Karnel${NC} ${GREEN1}Termux${NC}" "$W")${r_border}│${NC}${pad_r}"
  echo "${pad_l}${l_border}│${NC}$(_center "${DIM}by${NC} ${BOLD}${WHITE}israel${NC} ${WHITE}marques${NC}" "$W")${r_border}│${NC}${pad_r}"
  echo "${pad_l}${l_border}│${NC}${sp_line}${r_border}│${NC}${pad_r}"

  local dot_line="" dj
  for (( dj = 0; dj < W; dj++ )); do
    if (( dj == W/2 )); then
      dot_line+="${M_SHINE}◈${NC}"
    elif (( dj % 4 == 0 )); then
      dot_line+="${DIM}·${NC}"
    elif (( dj % 3 == 1 )); then
      dot_line+="${TP[$(( dj * 4 / W > 15 ? 15 : dj * 4 / W ))]}┄${NC}"
    else
      dot_line+="${DIM}─${NC}"
    fi
  done
  echo "${pad_l}${l_border}│${NC}${dot_line}${r_border}│${NC}${pad_r}"
  _render_frame_line "bot"
}

_render() {
  _render_top
  _render_figlet "" "${1:-}"
  _render_bottom
}

_show_tip() {
  local _tip_index_file="${XDG_CACHE_HOME:-$HOME/.cache}/karnel/.last_tip_index"
  local _tip_count=${#KARNEL_TIPS[@]}
  (( _tip_count > 0 )) || return 0

  local last_index=-1 new_index _tip _attempt=0
  if [[ -f "$_tip_index_file" ]]; then
    last_index=$(cat "$_tip_index_file" 2>/dev/null)
    [[ "$last_index" =~ ^[0-9]+$ ]] || last_index=-1
  fi

  # Bounded retry: a single-tip table (or an unlucky RANDOM) used to spin here.
  while :; do
    new_index=$(( RANDOM % _tip_count ))
    [[ "$new_index" != "$last_index" ]] && break
    _attempt=$((_attempt + 1))
    (( _attempt > 50 )) && break
  done

  printf '%s\n' "$new_index" >"$_tip_index_file" 2>/dev/null
  _tip="${KARNEL_TIPS[$new_index]:-}"
  [[ -n "$_tip" ]] && printf '\n %s●%s %sTip%s %s\n' "${TP[3]}" "$NC" "$GRAY" "$NC" "$_tip"
  return 0
}

_render_animated() {
  _render_top
  _render_figlet
  _render_bottom
  _show_tip
}

# Cache banner for clear() override (capture only, no terminal output).
# The key includes the terminal width: a cache rendered at 80 columns looked
# broken the moment the terminal was resized, because clear() replays it as-is.
_banner_cols_now=$(_banner_cols)
_banner_output=$(_render 2>/dev/null) || true
_karnel_banner_cache="${XDG_CACHE_HOME:-$HOME/.cache}/karnel/banner_cache.${_banner_cols_now}"
mkdir -p "$(dirname "$_karnel_banner_cache")" 2>/dev/null
if [[ -t 1 ]] && [[ -n "$_banner_output" ]]; then
  printf '%s\n' "$_banner_output" > "$_karnel_banner_cache" 2>/dev/null
fi
unset _banner_cols_now

banner_tip() { echo " ${TP[3]}●${NC} ${GRAY}Tip${NC} $*"; }

_karnel_tip_list=(
  "Keep Karnel updated: ${TP[3]}karnel update karnel${NC}"
  "Check your version: ${TP[3]}karnel --version${NC}"
  "Enable debug logs: ${TP[3]}export KARNEL_DEBUG=1${NC}"
  "Open framework docs: ${TP[3]}karnel open karnel${NC}"
  "Install everything: ${TP[3]}karnel install lang db dev npm${NC}"
  "Install specific AI tools: ${TP[3]}karnel install ai --opencode --ollama${NC}"
  "See what's installed: ${TP[3]}karnel list ai${NC}"
  "Read tool docs: ${TP[3]}karnel show ai --opencode${NC}"
  "Update a specific tool: ${TP[3]}karnel update ai --opencode${NC}"
  "Update all AI tools: ${TP[3]}karnel update ai${NC}"
  "Update all databases: ${TP[3]}karnel update db${NC}"
  "Update ZSH plugins: ${TP[3]}karnel update shell${NC}"
  "Remove a module: ${TP[3]}karnel uninstall npm${NC}"
  "Install all languages: ${TP[3]}karnel install lang${NC}"
  "Install Python: ${TP[3]}karnel install lang --python${NC}"
  "Install Rust: ${TP[3]}karnel install lang --rust${NC}"
  "Install Go: ${TP[3]}karnel install lang --golang${NC}"
  "Start PostgreSQL: ${TP[3]}karnel pg init${NC} then ${TP[3]}karnel pg start${NC}"
  "Open psql shell: ${TP[3]}karnel pg shell${NC}"
  "Install all AI agents: ${TP[3]}karnel install ai${NC}"
  "Install OpenCode: ${TP[3]}karnel install ai --opencode${NC}"
  "Install Claude Code: ${TP[3]}karnel install ai --claude-code${NC}"
  "Install Codex CLI: ${TP[3]}karnel install ai --codex${NC}"
  "Install Gemini CLI: ${TP[3]}karnel install ai --gemini-cli${NC}"
  "Install MiMo Code: ${TP[3]}karnel install ai --mimocode${NC}"
  "Install code-server: ${TP[3]}karnel install editor${NC}"
  "Fuzzy search: ${TP[3]}karnel install dev --fzf${NC}"
  "Modern ls: ${TP[3]}karnel install dev --lsd${NC}"
  "Syntax cat: ${TP[3]}karnel install dev --bat${NC}"
  "GitHub CLI: ${TP[3]}karnel install dev --gh${NC}"
  "Format shell scripts: ${TP[3]}karnel install dev --shfmt${NC}"
  "Process JSON: ${TP[3]}karnel install dev --jq${NC}"
  "Deploy to Vercel: ${TP[3]}karnel install npm --vercel${NC}"
  "TypeScript: ${TP[3]}karnel install npm --typescript${NC}"
  "Install ZSH + plugins: ${TP[3]}karnel install shell${NC}"
  "Customize Termux UI: ${TP[3]}karnel install ui${NC}"
  "Install banner: ${TP[3]}karnel install ui --banner${NC}"
  "Set API keys: ${TP[3]}karnel env set${NC}"
  "Second brain: ${TP[3]}karnel brain init${NC}"
  "Save memories: ${TP[3]}karnel brain save${NC}"
  "Voice-to-AI: ${TP[3]}karnel voice opencode${NC}"
  "Voice quick output: ${TP[3]}karnel voice text${NC}"
  "Init Next.js: ${TP[3]}cd my-app && karnel init next${NC}"
  "Init React+Vite: ${TP[3]}cd my-app && karnel init react${NC}"
  "Init Express API: ${TP[3]}cd api && karnel init express${NC}"
  "Init NestJS: ${TP[3]}cd backend && karnel init nest${NC}"
  "Install Qoder: ${TP[3]}karnel install ai --qoder${NC}"
  "Install Kilo Code: ${TP[3]}karnel install ai --kilocode-cli${NC}"
  "Install Freebuff: ${TP[3]}karnel install ai --freebuff${NC}"
  "Install Ollama (local LLMs): ${TP[3]}karnel install ai --ollama${NC}"
  "Install Qwen Code: ${TP[3]}karnel install ai --qwen-code${NC}"
  "Install Hermes Agent: ${TP[3]}karnel install ai --hermes-agent${NC}"
  "Install n8n automation: ${TP[3]}karnel install auto --n8n${NC}"
  "Install code-server: ${TP[3]}karnel install editor --code-server${NC}"
  "Install ImageMagick: ${TP[3]}karnel install dev --imagemagick${NC}"
  "Cloudflare Tunnel: ${TP[3]}karnel install dev --cloudflared${NC}"
  "Translate from terminal: ${TP[3]}karnel install dev --translate${NC}"
  "Share terminal instantly: ${TP[3]}karnel install dev --tmate${NC}"
  "Run Docker without root: ${TP[3]}karnel install dev --udocker${NC}"
  "Tunnel localhost: ${TP[3]}karnel install npm --ngrok${NC}"
  "Format code: ${TP[3]}karnel install npm --prettier${NC}"
  "Install Meslo Font: ${TP[3]}karnel install ui --font${NC}"
  "Green cursor: ${TP[3]}karnel install ui --cursor${NC}"
  "Extra keys bar: ${TP[3]}karnel install ui --extra-keys${NC}"
  "Powerlevel10k theme: ${TP[3]}karnel install shell --powerlevel10k${NC}"
  "Backup everything: ${TP[3]}karnel backup${NC}"
  "Restore from backup: ${TP[3]}karnel restore${NC}"
  "Run diagnostics: ${TP[3]}karnel doctor${NC}"
  "Search all tools: ${TP[3]}karnel search <query>${NC}"
  "Quick system status: ${TP[3]}karnel status${NC}"
  "israel marques 🇧🇷 — author of Karnel Termux"
)

# Re-keyed into an associative table so the random pick below works in both
# shells (a 0-based pick on a 1-based zsh array resolves to an empty tip).
declare -A KARNEL_TIPS=()
_tip_i=0
for _tip_entry in "${_karnel_tip_list[@]}"; do
  KARNEL_TIPS[$_tip_i]="$_tip_entry"
  _tip_i=$((_tip_i + 1))
done
unset _karnel_tip_list _tip_i _tip_entry

_block_input() {
  _OLD_STTY=$(stty -g 2>/dev/null || true)
  stty -echo -icanon min 0 time 0 2>/dev/null || true
}

_unblock_input() {
  stty "${_OLD_STTY:-sane}" 2>/dev/null || true
}

# Exportado para ser chamado pelo karnel.sh quando necessário
render_banner() {
  local _saved_traps _trap_line
  # Snapshot the caller's traps. Clearing EXIT/INT/TERM unconditionally used to
  # wipe whatever the shell rc (or a plugin) had installed before us.
  _saved_traps=$(trap 2>/dev/null)
  _block_input
  trap '_unblock_input' EXIT INT TERM
  _render_animated
  _unblock_input
  trap - EXIT INT TERM 2>/dev/null || true
  while IFS= read -r _trap_line; do
    [[ -n "$_trap_line" ]] && eval "$_trap_line"
  done <<< "$_saved_traps"
  echo
}
