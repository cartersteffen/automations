#!/usr/bin/env bash
set -euo pipefail

# Simple updater script for installed applications and plugins.
# It reads a manifest file with one entry per line. Each line can be:
# - brew:package_name
# - brew-cask:package_name
# - mas:app_id
# - npm:package_name (global)
# - pip:package_name
# - apt:package_name
# - snap:package_name
# - flatpak:package_name
# - custom:command to run (will be executed as-is)

MANIFEST_FILE=${1:-scripts/update-manifest.txt}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-artifacts}
mkdir -p "$ARTIFACTS_DIR"

log(){
  printf "%s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

if [ ! -f "$MANIFEST_FILE" ]; then
  log "Manifest file not found: $MANIFEST_FILE"
  exit 2
fi

log "Starting update run using manifest: $MANIFEST_FILE"

while IFS= read -r raw || [ -n "$raw" ]; do
  line=$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # skip empty and comment lines
  if [[ -z "$line" || "$line" =~ ^# ]]; then
    continue
  fi

  type=$(echo "$line" | cut -d':' -f1)
  value=$(echo "$line" | cut -d':' -f2-)

  log "Processing: $line"

  case "$type" in
    brew)
      if command -v brew >/dev/null 2>&1; then
        log "brew upgrade $value"
        brew upgrade "$value" || log "brew upgrade $value failed"
      else
        log "brew not found, skipping $value"
      fi
      ;;
    brew-cask)
      if command -v brew >/dev/null 2>&1; then
        log "brew upgrade --cask $value"
        brew upgrade --cask "$value" || log "brew upgrade --cask $value failed"
      else
        log "brew not found, skipping $value"
      fi
      ;;
    mas)
      if command -v mas >/dev/null 2>&1; then
        log "mas upgrade $value"
        mas upgrade "$value" || log "mas upgrade $value failed"
      else
        log "mas (Mac App Store CLI) not found, skipping $value"
      fi
      ;;
    npm)
      if command -v npm >/dev/null 2>&1; then
        log "npm update -g $value"
        npm update -g "$value" || log "npm update -g $value failed"
      else
        log "npm not found, skipping $value"
      fi
      ;;
    pip)
      if command -v pip3 >/dev/null 2>&1; then
        log "pip3 install --upgrade $value"
        pip3 install --upgrade "$value" || log "pip3 upgrade $value failed"
      elif command -v pip >/dev/null 2>&1; then
        log "pip install --upgrade $value"
        pip install --upgrade "$value" || log "pip upgrade $value failed"
      else
        log "pip not found, skipping $value"
      fi
      ;;
    apt)
      if command -v apt-get >/dev/null 2>&1; then
        log "apt-get update && apt-get install --only-upgrade -y $value"
        sudo apt-get update && sudo apt-get install --only-upgrade -y "$value" || log "apt upgrade $value failed"
      else
        log "apt-get not found, skipping $value"
      fi
      ;;
    snap)
      if command -v snap >/dev/null 2>&1; then
        log "snap refresh $value"
        sudo snap refresh "$value" || log "snap refresh $value failed"
      else
        log "snap not found, skipping $value"
      fi
      ;;
    flatpak)
      if command -v flatpak >/dev/null 2>&1; then
        log "flatpak update --app $value"
        flatpak update --app "$value" -y || log "flatpak update $value failed"
      else
        log "flatpak not found, skipping $value"
      fi
      ;;
    custom)
      log "Running custom command: $value"
      # shellcheck disable=SC2086
      eval "$value" || log "custom command failed: $value"
      ;;
    *)
      log "Unknown manifest type: $type (line: $line)"
      ;;
  esac
done < "$MANIFEST_FILE"

log "Update run completed"

exit 0
