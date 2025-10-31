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

# Track which applications need to be restarted
declare -a APPS_TO_RESTART=()

# Per-run reporting context
RUN_ID=$(date -u +'%Y%m%dT%H%M%SZ')
REPORT_FILE="$ARTIFACTS_DIR/update-report-$RUN_ID.txt"
UPDATED=()
REFRESHED=()
SKIPPED=()
FAILED=()
add_item(){ local arr_name=$1 item=$2; eval "$arr_name+=(\"$item\")"; }

log(){
  printf "%s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

# Function to restart applications that received updates
restart_updated_apps(){
  if [ ${#APPS_TO_RESTART[@]} -eq 0 ]; then
    log "No applications were updated, skipping restarts"
    return
  fi
  
  log "Restarting applications that received updates: ${APPS_TO_RESTART[*]}"
  
  for app in "${APPS_TO_RESTART[@]}"; do
    log "Restarting $app"
    osascript -e "tell application \"$app\" to quit" && sleep 2 && open -a "$app" || log "Failed to restart $app"
  done
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
        # Check if formula is installed
        if brew list "$value" >/dev/null 2>&1; then
          # Get current and latest versions
          current_version=$(brew list --versions "$value" | awk '{print $2}')
          latest_version=$(brew info --json=v2 "$value" | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
          
          if [ "$current_version" != "$latest_version" ]; then
            log "Upgrading $value from $current_version to $latest_version"
            if brew upgrade "$value"; then
              log "Successfully upgraded $value"
              add_item UPDATED "$value"
              # Add to restart list if it's an application
              case "$value" in
                "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                  APPS_TO_RESTART+=("$value")
                  ;;
              esac
            else
              log "brew upgrade $value failed"
              add_item FAILED "$value"
            fi
          else
            log "$value is already at latest version ($current_version), skipping"
            add_item SKIPPED "$value"
          fi
        else
          log "$value is not installed via brew, skipping"
          add_item SKIPPED "$value"
        fi
      else
        log "brew not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    brew-cask)
      if command -v brew >/dev/null 2>&1; then
        # Check if cask is installed
        if brew list --cask "$value" >/dev/null 2>&1; then
          # Get current and latest versions
          current_version=$(brew list --cask --versions "$value" | awk '{print $2}')
          latest_version=$(brew info --json=v2 --cask "$value" | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
          
          if [ "$current_version" != "$latest_version" ]; then
            log "Upgrading $value from $current_version to $latest_version"
            if brew upgrade --cask "$value"; then
              log "Successfully upgraded $value"
              add_item UPDATED "$value"
              # Add to restart list if it's an application
              case "$value" in
                "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker")
                  APPS_TO_RESTART+=("$value")
                  ;;
              esac
            else
              log "brew upgrade --cask $value failed"
              add_item FAILED "$value"
            fi
          else
            log "$value is already at latest version ($current_version), skipping"
            add_item SKIPPED "$value"
          fi
        else
          log "$value is not installed via brew cask, skipping"
          add_item SKIPPED "$value"
        fi
      else
        log "brew not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    mas)
      if command -v mas >/dev/null 2>&1; then
        log "mas upgrade $value"
        if mas upgrade "$value"; then
          add_item UPDATED "$value"
        else
          log "mas upgrade $value failed"
          add_item FAILED "$value"
        fi
      else
        log "mas (Mac App Store CLI) not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    npm)
      if command -v npm >/dev/null 2>&1; then
        log "npm update -g $value"
        if npm update -g "$value"; then
          add_item UPDATED "$value"
        else
          log "npm update -g $value failed"
          add_item FAILED "$value"
        fi
      else
        log "npm not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    pip)
      if command -v pip3 >/dev/null 2>&1; then
        log "pip3 install --upgrade $value"
        if pip3 install --upgrade "$value"; then
          add_item UPDATED "$value"
        else
          log "pip3 upgrade $value failed"
          add_item FAILED "$value"
        fi
      elif command -v pip >/dev/null 2>&1; then
        log "pip install --upgrade $value"
        if pip install --upgrade "$value"; then
          add_item UPDATED "$value"
        else
          log "pip upgrade $value failed"
          add_item FAILED "$value"
        fi
      else
        log "pip not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    apt)
      if command -v apt-get >/dev/null 2>&1; then
        log "apt-get update && apt-get install --only-upgrade -y $value"
        if sudo apt-get update && sudo apt-get install --only-upgrade -y "$value"; then
          add_item UPDATED "$value"
        else
          log "apt upgrade $value failed"
          add_item FAILED "$value"
        fi
      else
        log "apt-get not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    snap)
      if command -v snap >/dev/null 2>&1; then
        log "snap refresh $value"
        if sudo snap refresh "$value"; then
          add_item UPDATED "$value"
        else
          log "snap refresh $value failed"
          add_item FAILED "$value"
        fi
      else
        log "snap not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    flatpak)
      if command -v flatpak >/dev/null 2>&1; then
        log "flatpak update --app $value"
        if flatpak update --app "$value" -y; then
          add_item UPDATED "$value"
        else
          log "flatpak update $value failed"
          add_item FAILED "$value"
        fi
      else
        log "flatpak not found, skipping $value"
        add_item SKIPPED "$value"
      fi
      ;;
    custom)
      log "Running custom command: $value"
      # shellcheck disable=SC2086
      if eval "$value"; then
        # Check if this command updated extensions/plugins that require app restart
        case "$value" in
          *"code --install-extension"*)
            APPS_TO_RESTART+=("Visual Studio Code")
            ;;
          *"windsurf --update-extensions"*)
            APPS_TO_RESTART+=("Windsurf")
            ;;
          *"jetbrains-toolbox update-plugins"*)
            APPS_TO_RESTART+=("IntelliJ IDEA CE" "PyCharm CE" "Android Studio")
            ;;
        esac
        # Classify result for reporting
        if echo "$value" | grep -qE 'open -a\s+"[^"]+"\s+--args\s+--update-check'; then
          app_name=$(printf '%s' "$value" | sed -n 's/.*open -a "\([^"]\+\)".*/\1/p')
          if [ -n "$app_name" ]; then
            add_item REFRESHED "$app_name"
          else
            add_item REFRESHED "$value"
          fi
        else
          add_item UPDATED "$value"
        fi
      else
        log "custom command failed: $value"
        add_item FAILED "$value"
      fi
      ;;
    *)
      log "Unknown manifest type: $type (line: $line)"
      ;;
  esac
done < "$MANIFEST_FILE"

# Restart applications that received updates
restart_updated_apps

log "Update run completed"

# Emit minimal console summary and write report
summary_section(){
  local title=$1; shift
  # shellcheck disable=SC2206
  local items=("$@")
  if [ ${#items[@]} -gt 0 ]; then
    echo "$title (${#items[@]}): ${items[*]}"
  else
    echo "$title (0)"
  fi
}

log "Run summary:"
summary_section "Updated" "${UPDATED[@]}"
summary_section "Refreshed" "${REFRESHED[@]}"
summary_section "Skipped" "${SKIPPED[@]}"
summary_section "Failed" "${FAILED[@]}"

{
  echo "run_id=$RUN_ID"
  echo "updated_count=${#UPDATED[@]}"; echo "updated=${UPDATED[*]}"
  echo "refreshed_count=${#REFRESHED[@]}"; echo "refreshed=${REFRESHED[*]}"
  echo "skipped_count=${#SKIPPED[@]}"; echo "skipped=${SKIPPED[*]}"
  echo "failed_count=${#FAILED[@]}"; echo "failed=${FAILED[*]}"
} > "$REPORT_FILE"

log "Report saved: $REPORT_FILE"

exit 0
