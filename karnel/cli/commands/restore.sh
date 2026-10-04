#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"
import "@/utils/backup"

BACKUP_DIR="${KARNEL_DATA}/backups"

_restore_interrupt() {
  local status="$1"
  trap - HUP INT TERM
  if ! _backup_restore_rollback; then
    log_error "Restore interrupted; rollback incomplete, recovery data preserved: $_RESTORE_TRANSACTION/original"
    rm -rf -- "$_RESTORE_TMP"
  else
    rm -rf -- "$_RESTORE_TMP" "$_RESTORE_TRANSACTION"
    log_error "Restore interrupted; previous configuration was restored"
  fi
  exit "$status"
}

restore_main() {
  local file=""
  local cloud=false
  local list_only=false

  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        echo
        box "Restore"
        echo
        log_info "Usage: karnel restore [options] [file]"
        echo
        printf "    ${D_CYAN}%-24s${NC} %s\n" "karnel restore" "Restore latest backup"
        printf "    ${D_CYAN}%-24s${NC} %s\n" "karnel restore <file>" "Restore specific backup"
        printf "    ${D_CYAN}%-24s${NC} %s\n" "karnel restore --cloud" "Restore from cloud"
        printf "    ${D_CYAN}%-24s${NC} %s\n" "karnel restore --list" "List available backups"
        echo
        return
        ;;
      --cloud) cloud=true ;;
      --list|-l) list_only=true ;;
      *)
        if [[ -z "$file" ]]; then
          if [[ -f "$arg" ]]; then
            file="$arg"
          elif [[ -f "$BACKUP_DIR/$arg" ]]; then
            file="$BACKUP_DIR/$arg"
          else
            log_error "File not found: $arg"
            return 1
          fi
        else
          log_error "Restore accepts exactly one backup file"
          return 1
        fi
        ;;
    esac
  done

  if $list_only; then
    echo
    box "Available Backups"
    echo
    local count=0
    for f in "$BACKUP_DIR"/termux-*.tar.gz "$BACKUP_DIR"/snapshot-*.tar.gz; do
      [[ -f "$f" ]] || continue
      ((count++))
      local name size csum
      name=$(basename "$f")
      size=$(du -h "$f" | awk '{print $1}')
      csum=""
      [[ -f "$f.sha256" ]] && csum="$(cut -c1-16 < "$f.sha256")..."
      printf "  ${D_GREEN}%-30s${NC} %-8s %s\n" "$name" "$size" "$csum"
    done
    [[ $count -eq 0 ]] && echo "  No backups found." && echo "  Create one: karnel backup"
    echo
    return
  fi

  if $cloud; then
    if [[ "${KARNEL_ALLOW_UNAUTHENTICATED_CLOUD_RESTORE:-0}" != "1" ]]; then
      log_error "Cloud restore is disabled because a remote can replace both archive and checksum"
      log_info "Set KARNEL_ALLOW_UNAUTHENTICATED_CLOUD_RESTORE=1 only if you trust the remote"
      return 1
    fi
    command -v rclone &>/dev/null || { log_error "Install rclone: pkg install rclone"; return 1; }
    rclone listremotes 2>/dev/null | grep -q "^karnel:" || { log_error "Run 'rclone config' and name remote 'karnel'"; return 1; }
    log_info "Downloading from cloud..."
    mkdir -p "$BACKUP_DIR"
    rclone copy "karnel:backups/" "$BACKUP_DIR/" \
      --include "termux-*.tar.gz" --include "termux-*.tar.gz.sha256" 2>/dev/null || {
      log_error "Failed to download cloud backup"
      return 1
    }
    log_success "Downloaded from cloud"
  fi

  if [[ -z "$file" ]]; then
    file=$(_backup_latest "$BACKUP_DIR" 'termux-*.tar.gz') || file=""
  fi
  [[ -z "$file" || ! -f "$file" ]] && { log_error "No backup found. Run 'karnel backup' first"; return 1; }

  local ts
  ts=$(basename "$file" .tar.gz | sed 's/termux-//')
  echo
  box "Restore: $(basename "$file")"
  echo
  log_info "Size: $(du -h "$file" | awk '{print $1}')"
  log_info "Date: $(date -r "$file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
  if ! _backup_verify_checksum "$file"; then
    log_error "Missing or invalid checksum; refusing to restore"
    return 1
  fi
  _backup_archive_safe "$file" || { log_error "Unsafe or corrupt backup archive"; return 1; }
  log_success "Checksum verified"

  local tmp transaction
  tmp=$(mktemp -d "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX") || return 1
  if ! tar -xzf "$file" -C "$tmp" --no-same-owner --no-same-permissions 2>"$tmp/extract.err"; then
    log_error "Failed to extract backup: $(cat "$tmp/extract.err" 2>/dev/null)"
    rm -rf "$tmp"
    return 1
  fi
  local pkgs="$tmp/metadata/packages.list"
  if [[ ! -f "$pkgs" && -f "$tmp/packages.list" ]]; then
    pkgs="$tmp/packages.list"
    log_warn "Using package selections from a legacy snapshot"
  elif [[ ! -f "$pkgs" && -f "$BACKUP_DIR/packages-$ts.list" ]]; then
    pkgs="$BACKUP_DIR/packages-$ts.list"
    log_warn "Using legacy package-selection sidecar"
  fi
  [[ -f "$pkgs" ]] && log_info "$(wc -l <"$pkgs") packages to restore"

  local confirm=""
  echo
  read_confirm "Proceed with restore?" confirm n
  [[ "$confirm" != "y" ]] && { rm -rf "$tmp"; log_info "Cancelled"; return 0; }

  transaction=$(mktemp -d "$HOME/.karnel-restore.XXXXXX") || { rm -rf "$tmp"; return 1; }
  _backup_restore_reset
  if ! _restore_prepare_configs "$tmp" "$transaction"; then
    rm -rf -- "$tmp" "$transaction"
    _backup_restore_reset
    log_error "Failed to stage restore; no configuration was changed"
    return 1
  fi
  _RESTORE_TMP=$tmp
  _RESTORE_TRANSACTION=$transaction
  trap '_restore_interrupt 129' HUP
  trap '_restore_interrupt 130' INT
  trap '_restore_interrupt 143' TERM
  if ! _backup_restore_commit; then
    trap - HUP INT TERM
    rm -rf -- "$tmp"
    if [[ $_BACKUP_RESTORE_ROLLBACK_FAILED == 1 ]]; then
      log_error "Failed to apply and fully roll back restore; preserved recovery data: $transaction/original"
      return 1
    fi
    rm -rf -- "$transaction"
    _backup_restore_reset
    log_error "Failed to apply restore; previous configuration was restored"
    return 1
  fi
  trap - HUP INT TERM
  rm -rf -- "$transaction"
  _backup_restore_reset
  log_success "Configuration commit completed"

  # Package-manager transactions cannot be rolled back by the config transaction.
  if [[ -f "$pkgs" ]]; then
    log_info "Restoring package selections after the configuration commit..."
    if ! dpkg --set-selections <"$pkgs" 2>/dev/null || ! apt-get dselect-upgrade -y &>/dev/null; then
      rm -rf -- "$tmp"
      log_error "Package restoration failed or was partial; restored configuration remains committed"
      return 1
    fi
    log_success "Package list restored"
  fi
  rm -rf -- "$tmp"
  termux-reload-settings 2>/dev/null || true
  log_success "Configuration and package restoration completed"

  echo
  log_success "Done! Restart Termux or run: source ~/.zshrc"
  echo
}

_restore_prepare_configs() {
  local extracted="$1" transaction="$2" file source base

  for base in .bashrc .zshrc .profile .zshenv .inputrc; do
    file="$extracted/config/home/$base"
    [[ ! -f "$file" ]] || _backup_restore_prepare "$file" "$HOME/$base" "$transaction" || return 1
  done

  source="$extracted/config/termux"
  # Backups created before the transactional format nested the .termux directory.
  [[ -d "$source/.termux" ]] && source="$source/.termux"
  [[ ! -d "$source" ]] || _backup_restore_prepare "$source" "$HOME/.termux" "$transaction" || return 1

  source="$extracted/config/ssh"
  if [[ -d "$source" ]]; then
    _backup_restore_prepare "$source" "$HOME/.ssh" "$transaction" || return 1
    chmod 700 "${_BACKUP_RESTORE_STAGED[${#_BACKUP_RESTORE_STAGED[@]} - 1]}" || return 1
  fi

  for source in "$extracted/config/config"/*; do
    [[ -d "$source" ]] || continue
    base=$(basename "$source")
    _backup_restore_prepare "$source" "$HOME/.config/$base" "$transaction" || return 1
  done

  file="$extracted/config/prefix-etc/sources.list"
  [[ ! -f "$file" ]] || _backup_restore_prepare "$file" "$PREFIX/etc/apt/sources.list" "$transaction" || return 1
}
