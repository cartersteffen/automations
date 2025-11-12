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

# Function to map brew package names to macOS application names
get_app_name(){
  local package=$1
  case "$package" in
    "visual-studio-code")
      echo "Visual Studio Code"
      ;;
    "intellij-idea-ce"|"intellij-idea")
      # Check if IntelliJ IDEA CE or IntelliJ IDEA is installed
      if [ -d "/Applications/IntelliJ IDEA CE.app" ]; then
        echo "IntelliJ IDEA CE"
      elif [ -d "/Applications/IntelliJ IDEA.app" ]; then
        echo "IntelliJ IDEA"
      else
        echo "IntelliJ IDEA CE"
      fi
      ;;
    "pycharm-ce"|"pycharm")
      # Check if PyCharm CE or PyCharm is installed
      if [ -d "/Applications/PyCharm CE.app" ]; then
        echo "PyCharm CE"
      elif [ -d "/Applications/PyCharm.app" ]; then
        echo "PyCharm"
      else
        echo "PyCharm CE"
      fi
      ;;
    "postman")
      echo "Postman"
      ;;
    "docker")
      echo "Docker"
      ;;
    "windsurf")
      echo "Windsurf"
      ;;
    "figma")
      echo "Figma"
      ;;
    "github-copilot-for-xcode")
      echo "GitHub Copilot for Xcode"
      ;;
    "android-studio")
      echo "Android Studio"
      ;;
    "cursor")
      echo "Cursor"
      ;;
    *)
      # Try to convert common patterns: lowercase-with-hyphens -> Title Case With Spaces
      echo "$package" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1'
      ;;
  esac
}

# Function to restart applications that received updates
restart_updated_apps(){
  if [ ${#APPS_TO_RESTART[@]} -eq 0 ]; then
    log "No applications were updated, skipping restarts"
    return
  fi
  
  log "Restarting applications that received updates: ${APPS_TO_RESTART[*]}"
  
  for package in "${APPS_TO_RESTART[@]}"; do
    app_name=$(get_app_name "$package")
    log "Restarting $app_name (package: $package)"
    
    # Try to quit the application if it's running (ignore errors if not running)
    log "Closing $app_name (if running)"
    osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || true
    
    # Wait for the app to fully close (give it time to save state)
    sleep 3
    
    # Reopen the application
    log "Opening $app_name"
    if open -a "$app_name" 2>/dev/null; then
      log "Successfully restarted $app_name"
    else
      log "Failed to restart $app_name - it may not be installed or the app name may be incorrect"
    fi
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
          # Get current and latest versions (best-effort; do not exit on parsing failure)
          current_version=$(brew list --versions "$value" | awk '{print $2}' || true)
          latest_version=$(brew info --json=v2 "$value" 2>/dev/null | awk -F '"' '/"version"/ {print $4; exit}' || true)

          if [ -n "$current_version" ] && [ -n "$latest_version" ] && [ "$current_version" != "$latest_version" ]; then
            log "Upgrading $value from $current_version to $latest_version"
            if brew upgrade "$value"; then
              # Verify the version actually changed after upgrade
              new_version=$(brew list --versions "$value" | awk '{print $2}' || true)
              if [ -n "$new_version" ] && [ "$new_version" != "$current_version" ]; then
                log "Successfully upgraded $value from $current_version to $new_version"
                add_item UPDATED "$value"
                # Add to restart list if it's an application
                case "$value" in
                  "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                    APPS_TO_RESTART+=("$value")
                    ;;
                esac
              else
                log "Upgrade completed but version unchanged (already at latest: $current_version)"
                add_item SKIPPED "$value"
              fi
            else
              log "brew upgrade $value failed"
              add_item FAILED "$value"
            fi
          else
            # If version parsing failed, attempt upgrade anyway (safe if up-to-date)
            if [ -z "$current_version" ] || [ -z "$latest_version" ]; then
              log "Version check unavailable for $value, attempting upgrade"
              if brew upgrade "$value"; then
                # Check if version changed after upgrade
                new_version=$(brew list --versions "$value" | awk '{print $2}' || true)
                if [ -n "$new_version" ] && [ -n "$current_version" ] && [ "$new_version" != "$current_version" ]; then
                  log "Upgrade completed: $value updated from $current_version to $new_version"
                  add_item UPDATED "$value"
                  # Add to restart list if it's an application
                  case "$value" in
                    "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                      APPS_TO_RESTART+=("$value")
                      ;;
                  esac
                else
                  log "Upgrade attempted for $value (may already be latest)"
                  add_item UPDATED "$value"
                fi
              else
                log "brew upgrade $value failed"
                add_item FAILED "$value"
              fi
            else
              log "$value is already at latest version ($current_version), skipping"
              add_item SKIPPED "$value"
            fi
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
          # Get current and latest versions (best-effort; do not exit on parsing failure)
          current_version=$(brew list --cask --versions "$value" | awk '{print $2}' || true)
          latest_version=$(brew info --json=v2 --cask "$value" 2>/dev/null | awk -F '"' '/"version"/ {print $4; exit}' || true)

          if [ -n "$current_version" ] && [ -n "$latest_version" ] && [ "$current_version" != "$latest_version" ]; then
            log "Upgrading $value from $current_version to $latest_version"
            if brew upgrade --cask "$value"; then
              # Verify the version actually changed after upgrade
              new_version=$(brew list --cask --versions "$value" | awk '{print $2}' || true)
              if [ -n "$new_version" ] && [ "$new_version" != "$current_version" ]; then
                log "Successfully upgraded $value from $current_version to $new_version"
                add_item UPDATED "$value"
                # Add to restart list if it's an application
                case "$value" in
                  "visual-studio-code"|"intellij-idea"|"pycharm"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                    APPS_TO_RESTART+=("$value")
                    ;;
                esac
              else
                log "Upgrade completed but version unchanged (already at latest: $current_version)"
                add_item SKIPPED "$value"
              fi
            else
              log "brew upgrade --cask $value failed"
              add_item FAILED "$value"
            fi
          else
            # If version parsing failed, attempt upgrade anyway (safe if up-to-date)
            if [ -z "$current_version" ] || [ -z "$latest_version" ]; then
              log "Version check unavailable for cask $value, attempting upgrade"
              if brew upgrade --cask "$value"; then
                # Check if version changed after upgrade
                new_version=$(brew list --cask --versions "$value" | awk '{print $2}' || true)
                if [ -n "$new_version" ] && [ -n "$current_version" ] && [ "$new_version" != "$current_version" ]; then
                  log "Upgrade completed: $value updated from $current_version to $new_version"
                  add_item UPDATED "$value"
                  # Add to restart list if it's an application
                  case "$value" in
                    "visual-studio-code"|"intellij-idea"|"pycharm"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                      APPS_TO_RESTART+=("$value")
                      ;;
                  esac
                else
                  log "Upgrade attempted for cask $value (may already be latest)"
                  add_item UPDATED "$value"
                fi
              else
                log "brew upgrade --cask $value failed"
                add_item FAILED "$value"
              fi
            else
              log "$value is already at latest version ($current_version), skipping"
              add_item SKIPPED "$value"
            fi
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
      # Temporarily disable set -u for custom commands to avoid unbound variable errors in subshells
      # Wrap entire execution in subshell to ensure set +u applies to all subshells created by pipes
      # shellcheck disable=SC2086
      (
        set +u
        set +e  # Don't exit on error in subshell
        eval "$value" 2>&1
        exit_code=$?
        exit $exit_code
      )
      cmd_exit=$?
      if [ $cmd_exit -eq 0 ]; then
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
summary_section "Updated" "${UPDATED[@]:-}"
summary_section "Refreshed" "${REFRESHED[@]:-}"
summary_section "Skipped" "${SKIPPED[@]:-}"
summary_section "Failed" "${FAILED[@]:-}"

{
  echo "run_id=$RUN_ID"
  echo "updated_count=${#UPDATED[@]}"
  [ ${#UPDATED[@]} -gt 0 ] && echo "updated=${UPDATED[*]}" || echo "updated="
  echo "refreshed_count=${#REFRESHED[@]}"
  [ ${#REFRESHED[@]} -gt 0 ] && echo "refreshed=${REFRESHED[*]}" || echo "refreshed="
  echo "skipped_count=${#SKIPPED[@]}"
  [ ${#SKIPPED[@]} -gt 0 ] && echo "skipped=${SKIPPED[*]}" || echo "skipped="
  echo "failed_count=${#FAILED[@]}"
  [ ${#FAILED[@]} -gt 0 ] && echo "failed=${FAILED[*]}" || echo "failed="
} > "$REPORT_FILE"

log "Report saved: $REPORT_FILE"

exit 0
