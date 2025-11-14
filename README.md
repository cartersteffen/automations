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

- Each run emits a console summary showing counts of Updated, Refreshed, Skipped, and Failed items.
- **Resilient execution**: The script continues trying all updates even if some fail, ensuring maximum coverage.
- **JSON reporting**: All reports are now in JSON format for easy parsing and analysis.

### Report Files

1. **Per-run detailed report**: `artifacts/update-report-<RUN_ID>.json`
   - Complete details for every package processed
   - Timestamps, version changes, and error messages
   - Status for each package (updated, refreshed, skipped, failed)

2. **Summary file**: `artifacts/update-summary.json`
   - Historical tracking of all runs
   - Quick overview of each run's results
   - Links to detailed reports

### Example Report Structure

```json
{
  "run_id": "20250101T000000Z",
  "start_time": "2025-01-01T00:00:00Z",
  "end_time": "2025-01-01T00:15:30Z",
  "summary": {
    "updated": 5,
    "refreshed": 2,
    "skipped": 10,
    "failed": 1,
    "total": 18
  },
  "results": [
    {
      "timestamp": "2025-01-01T00:01:23Z",
      "status": "updated",
      "type": "brew",
      "package": "node",
      "old_version": "20.0.0",
      "new_version": "20.1.0"
    },
    {
      "timestamp": "2025-01-01T00:02:45Z",
      "status": "failed",
      "type": "npm",
      "package": "typescript",
      "error": "EACCES: permission denied"
    }
  ]
}
```

For more details on the reporting format and usage examples, see [REPORTING.md](REPORTING.md).

Next steps and ideas

- Add email or Slack notifications on update success/failure.
- Add a dry-run mode to the script that shows what would change.
- Add per-entry version checks and only upgrade if a newer version exists.
