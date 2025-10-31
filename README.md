# Auto Updater

This repository contains a small automation to check for updates for installed applications and plugins and apply them automatically.

Files added:

- `.github/workflows/auto-update.yml` - GitHub Actions workflow; triggered by a button (workflow_dispatch) and a daily cron at 00:00 UTC.
- `automations/update_all.sh` - The updater script that reads `automations/update-manifest.txt` and runs the appropriate update commands.
- `automations/update-manifest.txt` - A sample manifest listing packages to update.

How it runs

- The workflow is intended to run on a self-hosted runner. The runner must have the label `auto-updater` so the workflow targets it.
- When executed, the workflow checks out the repo, makes the updater script executable, runs it using the manifest, and uploads a log artifact.

Setting up a self-hosted runner (high level)

1. On your machine (macOS, Linux, or Windows), follow GitHub's instructions to create a self-hosted runner for your repository or organization.
2. When configuring the runner, add the label `auto-updater` so the workflow picks it up.
3. Ensure the runner is running as a service or process so it can accept jobs.

Security and safety notes

- This script runs commands that update software on the machine. Run it only on machines you control and trust.
- The manifest supports a `custom:` type which will execute arbitrary shell commands. Be careful with entries here.
- The workflow is designed to run on a self-hosted runner for safety — it will not modify GitHub-hosted runners or other remote environments.

Extending the manifest

- You can add entries in `automations/update-manifest.txt` using the supported prefixes:

  - `brew:` for Homebrew packages
  - `brew-cask:` for Homebrew casks
  - `mas:` for Mac App Store IDs (requires `mas` CLI)
  - `npm:` for global npm packages
  - `pip:` for Python packages (pip3 preferred)
  - `apt:`, `snap:`, `flatpak:` for Linux package managers
  - `custom:` to run any shell command

Running locally

Make the script executable:

```sh
chmod +x automations/update_all.sh
```

Run:

```sh
./automations/update_all.sh automations/update-manifest.txt
```

Logs

- The workflow saves the update log as an artifact named `update-logs`.

Run report and console summary

- Each run now emits a minimal console summary with counts and the names of items per action: Updated, Refreshed, Skipped, Failed.
- A per-run text report is written to `artifacts/update-report-<UTC_TIMESTAMP>.txt`.
- Report format (key=value lines):

```text
run_id=20250101T000000Z
updated_count=2
updated=postman visual-studio-code
refreshed_count=1
refreshed=Android Studio
skipped_count=3
skipped=intellij-idea brew git
failed_count=0
failed=
```

- The most recent report can be identified by the highest timestamp in the filename.

Next steps and ideas

- Add email or Slack notifications on update success/failure.
- Add a dry-run mode to the script that shows what would change.
- Add per-entry version checks and only upgrade if a newer version exists.
