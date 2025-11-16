#!/usr/bin/env bash
set -uo pipefail

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
RUN_START_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
REPORT_FILE="$ARTIFACTS_DIR/update-report-$RUN_ID.json"
SUMMARY_FILE="$ARTIFACTS_DIR/update-summary.json"

# Detailed tracking arrays for JSON output
declare -a RESULTS=()

# Add detailed result entry
add_result() {
  local status=$1 type=$2 package=$3
  local old_version=${4:-} new_version=${5:-} error_msg=${6:-}
  local timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  # Escape JSON strings
  package_escaped=$(printf '%s' "$package" | sed 's/\\/\\\\/g; s/"/\\"/g')
  old_version_escaped=$(printf '%s' "$old_version" | sed 's/\\/\\\\/g; s/"/\\"/g')
  new_version_escaped=$(printf '%s' "$new_version" | sed 's/\\/\\\\/g; s/"/\\"/g')
  error_escaped=$(printf '%s' "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')

  local entry="{\"timestamp\":\"$timestamp\",\"status\":\"$status\",\"type\":\"$type\",\"package\":\"$package_escaped\""
  [ -n "$old_version" ] && entry="$entry,\"old_version\":\"$old_version_escaped\""
  [ -n "$new_version" ] && entry="$entry,\"new_version\":\"$new_version_escaped\""
  [ -n "$error_msg" ] && entry="$entry,\"error\":\"$error_escaped\""
  entry="$entry}"

  RESULTS+=("$entry")
}

log(){
  printf "%s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

# Sudo password management
# This script uses interactive password prompts for security.
# For automated runs, configure passwordless sudo (see documentation below).
SUDO_PASSWORD=""
SUDO_PASSWORD_SET=false

# Function to get sudo password if needed
get_sudo_password() {
  if [ "$SUDO_PASSWORD_SET" = true ]; then
    return 0
  fi

  # Check if passwordless sudo is available
  if sudo -n true 2>/dev/null; then
    log "Passwordless sudo is available - no password needed"
    SUDO_PASSWORD_SET=true
    return 0
  fi

  # Check if running in interactive terminal
  if [ ! -t 0 ]; then
    log "ERROR: Sudo password required but running in non-interactive mode."
    log ""
    log "To fix this, configure passwordless sudo for package management commands:"
    log "  1. Run: sudo visudo"
    log "  2. Add a line like (replace USERNAME with your username):"
    log "     USERNAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/snap"
    log ""
    log "Or run this script in an interactive terminal where you can enter the password."
    return 1
  fi

  # Interactive mode: prompt for password once
  if [ -z "$SUDO_PASSWORD" ]; then
    log "Sudo password required for package updates."
    log "You'll only need to enter this once - it will be reused for all sudo commands."
    printf "Please enter your sudo password: "
    read -rs SUDO_PASSWORD
    echo ""  # New line after hidden password input
    SUDO_PASSWORD_SET=true
    
    # Verify the password works
    if ! echo "$SUDO_PASSWORD" | sudo -S true 2>/dev/null; then
      log "ERROR: Invalid password. Please try again."
      SUDO_PASSWORD=""
      SUDO_PASSWORD_SET=false
      return 1
    fi
    log "Sudo password verified - will be reused for remaining commands"
  fi
}

# Function to run sudo command with automatic password
run_sudo() {
  # Check if passwordless sudo works
  if sudo -n true 2>/dev/null; then
    sudo "$@"
    return $?
  fi
  
  # Get password if needed
  if ! get_sudo_password; then
    return 1
  fi
  
  # Use sudo -S to pass password via stdin
  echo "$SUDO_PASSWORD" | sudo -S "$@"
  return $?
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
      if ! command -v brew >/dev/null 2>&1; then
        log "brew not found, skipping $value"
        add_result "skipped" "brew" "$value" "" "" "brew command not found"
        continue
      fi

      if ! brew list "$value" >/dev/null 2>&1; then
        log "$value is not installed via brew, skipping"
        add_result "skipped" "brew" "$value" "" "" "not installed"
        continue
      fi

      # Get current and latest versions (best-effort; do not exit on parsing failure)
      current_version=$(brew list --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
      latest_version=$(brew info --json=v2 "$value" 2>/dev/null | awk -F '"' '/"version"/ {print $4; exit}' || echo "")

      if [ -n "$current_version" ] && [ -n "$latest_version" ] && [ "$current_version" != "$latest_version" ]; then
        log "Upgrading $value from $current_version to $latest_version"
        error_output=$(brew upgrade "$value" 2>&1) || upgrade_failed=$?
        if [ -z "${upgrade_failed:-}" ]; then
          # Verify the version actually changed after upgrade
          new_version=$(brew list --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
          if [ -n "$new_version" ] && [ "$new_version" != "$current_version" ]; then
            log "Successfully upgraded $value from $current_version to $new_version"
            add_result "updated" "brew" "$value" "$current_version" "$new_version"
            # Add to restart list if it's an application
            case "$value" in
              "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                APPS_TO_RESTART+=("$value")
                ;;
            esac
          else
            log "Upgrade completed but version unchanged (already at latest: $current_version)"
            add_result "skipped" "brew" "$value" "$current_version" "$current_version"
          fi
        else
          log "brew upgrade $value failed: $error_output"
          add_result "failed" "brew" "$value" "$current_version" "" "$error_output"
        fi
        unset upgrade_failed
      else
        # If version parsing failed, attempt upgrade anyway (safe if up-to-date)
        if [ -z "$current_version" ] || [ -z "$latest_version" ]; then
          log "Version check unavailable for $value, attempting upgrade"
          error_output=$(brew upgrade "$value" 2>&1) || upgrade_failed=$?
          if [ -z "${upgrade_failed:-}" ]; then
            # Check if version changed after upgrade
            new_version=$(brew list --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
            if [ -n "$new_version" ] && [ -n "$current_version" ] && [ "$new_version" != "$current_version" ]; then
              log "Upgrade completed: $value updated from $current_version to $new_version"
              add_result "updated" "brew" "$value" "$current_version" "$new_version"
              # Add to restart list if it's an application
              case "$value" in
                "visual-studio-code"|"intellij-idea-ce"|"pycharm-ce"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                  APPS_TO_RESTART+=("$value")
                  ;;
              esac
            else
              log "Upgrade attempted for $value (may already be latest)"
              add_result "updated" "brew" "$value" "$current_version" "$new_version"
            fi
          else
            log "brew upgrade $value failed: $error_output"
            add_result "failed" "brew" "$value" "$current_version" "" "$error_output"
          fi
          unset upgrade_failed
        else
          log "$value is already at latest version ($current_version), skipping"
          add_result "skipped" "brew" "$value" "$current_version" "$current_version"
        fi
      fi
      ;;
    brew-cask)
      if ! command -v brew >/dev/null 2>&1; then
        log "brew not found, skipping $value"
        add_result "skipped" "brew-cask" "$value" "" "" "brew command not found"
        continue
      fi

      if ! brew list --cask "$value" >/dev/null 2>&1; then
        log "$value is not installed via brew cask, skipping"
        add_result "skipped" "brew-cask" "$value" "" "" "not installed"
        continue
      fi

      # Get current and latest versions (best-effort; do not exit on parsing failure)
      current_version=$(brew list --cask --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
      latest_version=$(brew info --json=v2 --cask "$value" 2>/dev/null | awk -F '"' '/"version"/ {print $4; exit}' || echo "")

      if [ -n "$current_version" ] && [ -n "$latest_version" ] && [ "$current_version" != "$latest_version" ]; then
        log "Upgrading $value from $current_version to $latest_version"
        error_output=$(brew upgrade --cask "$value" 2>&1) || upgrade_failed=$?
        if [ -z "${upgrade_failed:-}" ]; then
          # Verify the version actually changed after upgrade
          new_version=$(brew list --cask --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
          if [ -n "$new_version" ] && [ "$new_version" != "$current_version" ]; then
            log "Successfully upgraded $value from $current_version to $new_version"
            add_result "updated" "brew-cask" "$value" "$current_version" "$new_version"
            # Add to restart list if it's an application
            case "$value" in
              "visual-studio-code"|"intellij-idea"|"pycharm"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                APPS_TO_RESTART+=("$value")
                ;;
            esac
          else
            log "Upgrade completed but version unchanged (already at latest: $current_version)"
            add_result "skipped" "brew-cask" "$value" "$current_version" "$current_version"
          fi
        else
          log "brew upgrade --cask $value failed: $error_output"
          add_result "failed" "brew-cask" "$value" "$current_version" "" "$error_output"
        fi
        unset upgrade_failed
      else
        # If version parsing failed, attempt upgrade anyway (safe if up-to-date)
        if [ -z "$current_version" ] || [ -z "$latest_version" ]; then
          log "Version check unavailable for cask $value, attempting upgrade"
          error_output=$(brew upgrade --cask "$value" 2>&1) || upgrade_failed=$?
          if [ -z "${upgrade_failed:-}" ]; then
            # Check if version changed after upgrade
            new_version=$(brew list --cask --versions "$value" 2>/dev/null | awk '{print $2}' || echo "")
            if [ -n "$new_version" ] && [ -n "$current_version" ] && [ "$new_version" != "$current_version" ]; then
              log "Upgrade completed: $value updated from $current_version to $new_version"
              add_result "updated" "brew-cask" "$value" "$current_version" "$new_version"
              # Add to restart list if it's an application
              case "$value" in
                "visual-studio-code"|"intellij-idea"|"pycharm"|"postman"|"docker"|"windsurf"|"figma"|"github-copilot-for-xcode"|"android-studio"|"cursor")
                  APPS_TO_RESTART+=("$value")
                  ;;
              esac
            else
              log "Upgrade attempted for cask $value (may already be latest)"
              add_result "updated" "brew-cask" "$value" "$current_version" "$new_version"
            fi
          else
            log "brew upgrade --cask $value failed: $error_output"
            add_result "failed" "brew-cask" "$value" "$current_version" "" "$error_output"
          fi
          unset upgrade_failed
        else
          log "$value is already at latest version ($current_version), skipping"
          add_result "skipped" "brew-cask" "$value" "$current_version" "$current_version"
        fi
      fi
      ;;
    mas)
      if ! command -v mas >/dev/null 2>&1; then
        log "mas (Mac App Store CLI) not found, skipping $value"
        add_result "skipped" "mas" "$value" "" "" "mas command not found"
        continue
      fi

      log "mas upgrade $value"
      error_output=$(mas upgrade "$value" 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "mas" "$value"
      else
        log "mas upgrade $value failed: $error_output"
        add_result "failed" "mas" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    npm)
      if ! command -v npm >/dev/null 2>&1; then
        log "npm not found, skipping $value"
        add_result "skipped" "npm" "$value" "" "" "npm command not found"
        continue
      fi

      log "npm update -g $value"
      error_output=$(npm update -g "$value" 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "npm" "$value"
      else
        log "npm update -g $value failed: $error_output"
        add_result "failed" "npm" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    pip)
      if command -v pip3 >/dev/null 2>&1; then
        pip_cmd="pip3"
      elif command -v pip >/dev/null 2>&1; then
        pip_cmd="pip"
      else
        log "pip not found, skipping $value"
        add_result "skipped" "pip" "$value" "" "" "pip command not found"
        continue
      fi

      log "$pip_cmd install --upgrade $value"
      error_output=$($pip_cmd install --upgrade "$value" 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "pip" "$value"
      else
        log "$pip_cmd upgrade $value failed: $error_output"
        add_result "failed" "pip" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    apt)
      if ! command -v apt-get >/dev/null 2>&1; then
        log "apt-get not found, skipping $value"
        add_result "skipped" "apt" "$value" "" "" "apt-get command not found"
        continue
      fi

      log "apt-get update && apt-get install --only-upgrade -y $value"
      error_output=$(run_sudo apt-get update && run_sudo apt-get install --only-upgrade -y "$value" 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "apt" "$value"
      else
        log "apt upgrade $value failed: $error_output"
        add_result "failed" "apt" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    snap)
      if ! command -v snap >/dev/null 2>&1; then
        log "snap not found, skipping $value"
        add_result "skipped" "snap" "$value" "" "" "snap command not found"
        continue
      fi

      log "snap refresh $value"
      error_output=$(run_sudo snap refresh "$value" 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "snap" "$value"
      else
        log "snap refresh $value failed: $error_output"
        add_result "failed" "snap" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    flatpak)
      if ! command -v flatpak >/dev/null 2>&1; then
        log "flatpak not found, skipping $value"
        add_result "skipped" "flatpak" "$value" "" "" "flatpak command not found"
        continue
      fi

      log "flatpak update --app $value"
      error_output=$(flatpak update --app "$value" -y 2>&1) || upgrade_failed=$?
      if [ -z "${upgrade_failed:-}" ]; then
        add_result "updated" "flatpak" "$value"
      else
        log "flatpak update $value failed: $error_output"
        add_result "failed" "flatpak" "$value" "" "" "$error_output"
      fi
      unset upgrade_failed
      ;;
    custom)
      log "Running custom command: $value"

      # If this is "brew upgrade" (without package name), capture cask versions before upgrade
      # Use a Bash 3.2 compatible approach (no associative arrays)
      if echo "$value" | grep -qE '^brew upgrade\s*$'; then
        # List of casks we care about from the manifest
        casks_to_check="postman intellij-idea pycharm visual-studio-code windsurf figma github-copilot-for-xcode android-studio cursor docker"
        cask_versions_before=""

        for cask in $casks_to_check; do
          if brew list --cask "$cask" >/dev/null 2>&1; then
            version=$(brew list --cask --versions "$cask" 2>/dev/null | awk '{print $2}' || echo "")
            if [ -n "$version" ]; then
              cask_versions_before="$cask_versions_before$cask:$version "
            fi
          fi
        done
      fi

      # Temporarily disable set -u for custom commands to avoid unbound variable errors in subshells
      # Wrap entire execution in subshell to ensure set +u applies to all subshells created by pipes
      # shellcheck disable=SC2086
      error_output=$(
        (
          set +u
          set +e  # Don't exit on error in subshell
          eval "$value" 2>&1
          exit_code=$?
          exit $exit_code
        )
      ) || cmd_exit=$?

      if [ -z "${cmd_exit:-}" ]; then
        # If this was "brew upgrade", check which casks were upgraded
        if echo "$value" | grep -qE '^brew upgrade\s*$'; then
          for cask in $casks_to_check; do
            # Extract version from cask_versions_before
            old_version=$(echo "$cask_versions_before" | grep -o "$cask:[^ ]*" | cut -d: -f2)

            if [ -n "$old_version" ] && brew list --cask "$cask" >/dev/null 2>&1; then
              new_version=$(brew list --cask --versions "$cask" 2>/dev/null | awk '{print $2}' || echo "")
              if [ -n "$new_version" ] && [ "$new_version" != "$old_version" ]; then
                log "Detected $cask was upgraded from $old_version to $new_version by brew upgrade"
                APPS_TO_RESTART+=("$cask")
              fi
            fi
          done
        fi

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
            add_result "refreshed" "custom" "$app_name"
          else
            add_result "refreshed" "custom" "$value"
          fi
        else
          add_result "updated" "custom" "$value"
        fi
      else
        log "custom command failed: $value - $error_output"
        add_result "failed" "custom" "$value" "" "" "$error_output"
      fi
      unset cmd_exit
      ;;
    *)
      log "Unknown manifest type: $type (line: $line)"
      ;;
  esac
done < "$MANIFEST_FILE"

# Restart applications that received updates
restart_updated_apps

log "Update run completed"

RUN_END_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Calculate summary statistics from results
updated_count=0
refreshed_count=0
skipped_count=0
failed_count=0

for result in "${RESULTS[@]}"; do
  status=$(echo "$result" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
  case "$status" in
    updated) ((updated_count++)) || true ;;
    refreshed) ((refreshed_count++)) || true ;;
    skipped) ((skipped_count++)) || true ;;
    failed) ((failed_count++)) || true ;;
  esac
done

# Emit console summary
log "Run summary:"
log "  Updated: $updated_count"
log "  Refreshed: $refreshed_count"
log "  Skipped: $skipped_count"
log "  Failed: $failed_count"

# Generate JSON report for this run
{
  echo "{"
  echo "  \"run_id\": \"$RUN_ID\","
  echo "  \"start_time\": \"$RUN_START_TIME\","
  echo "  \"end_time\": \"$RUN_END_TIME\","
  echo "  \"summary\": {"
  echo "    \"updated\": $updated_count,"
  echo "    \"refreshed\": $refreshed_count,"
  echo "    \"skipped\": $skipped_count,"
  echo "    \"failed\": $failed_count,"
  echo "    \"total\": $((updated_count + refreshed_count + skipped_count + failed_count))"
  echo "  },"
  echo "  \"results\": ["

  # Output all results with proper JSON array formatting
  for i in "${!RESULTS[@]}"; do
    echo -n "    ${RESULTS[$i]}"
    if [ $i -lt $((${#RESULTS[@]} - 1)) ]; then
      echo ","
    else
      echo ""
    fi
  done

  echo "  ]"
  echo "}"
} > "$REPORT_FILE"

log "Detailed report saved: $REPORT_FILE"

# Update or create summary file that tracks all runs
if [ -f "$SUMMARY_FILE" ]; then
  # Read existing summary and append new run
  existing_runs=$(sed -n '/"runs": \[/,/\]/p' "$SUMMARY_FILE" | sed '1d;$d' | sed '$s/,$//')

  {
    echo "{"
    echo "  \"last_updated\": \"$RUN_END_TIME\","
    echo "  \"runs\": ["
    [ -n "$existing_runs" ] && echo "$existing_runs,"
    echo "    {"
    echo "      \"run_id\": \"$RUN_ID\","
    echo "      \"start_time\": \"$RUN_START_TIME\","
    echo "      \"end_time\": \"$RUN_END_TIME\","
    echo "      \"summary\": {"
    echo "        \"updated\": $updated_count,"
    echo "        \"refreshed\": $refreshed_count,"
    echo "        \"skipped\": $skipped_count,"
    echo "        \"failed\": $failed_count,"
    echo "        \"total\": $((updated_count + refreshed_count + skipped_count + failed_count))"
    echo "      },"
    echo "      \"report_file\": \"$REPORT_FILE\""
    echo "    }"
    echo "  ]"
    echo "}"
  } > "$SUMMARY_FILE"
else
  # Create new summary file
  {
    echo "{"
    echo "  \"last_updated\": \"$RUN_END_TIME\","
    echo "  \"runs\": ["
    echo "    {"
    echo "      \"run_id\": \"$RUN_ID\","
    echo "      \"start_time\": \"$RUN_START_TIME\","
    echo "      \"end_time\": \"$RUN_END_TIME\","
    echo "      \"summary\": {"
    echo "        \"updated\": $updated_count,"
    echo "        \"refreshed\": $refreshed_count,"
    echo "        \"skipped\": $skipped_count,"
    echo "        \"failed\": $failed_count,"
    echo "        \"total\": $((updated_count + refreshed_count + skipped_count + failed_count))"
    echo "      },"
    echo "      \"report_file\": \"$REPORT_FILE\""
    echo "    }"
    echo "  ]"
    echo "}"
  } > "$SUMMARY_FILE"
fi

log "Summary file updated: $SUMMARY_FILE"

exit 0
