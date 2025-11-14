# Update Script Reporting Format

## Overview

The update script now uses JSON format for all reports, making it much easier to parse, analyze, and track update history over time.

## Key Improvements

### 1. Resilient Error Handling
- **Removed `set -e`**: The script no longer exits on the first failure
- **Continue on error**: Each package update is attempted independently, even if previous ones fail
- **Detailed error capture**: Error messages are captured and included in the JSON report

### 2. JSON Report Format

#### Per-Run Report
Each run generates a detailed JSON report: `artifacts/update-report-{RUN_ID}.json`

```json
{
  "run_id": "20241114T123456Z",
  "start_time": "2024-11-14T12:34:56Z",
  "end_time": "2024-11-14T12:45:30Z",
  "summary": {
    "updated": 5,
    "refreshed": 2,
    "skipped": 10,
    "failed": 1,
    "total": 18
  },
  "results": [
    {
      "timestamp": "2024-11-14T12:35:10Z",
      "status": "updated",
      "type": "brew",
      "package": "node",
      "old_version": "20.0.0",
      "new_version": "20.1.0"
    },
    {
      "timestamp": "2024-11-14T12:36:20Z",
      "status": "failed",
      "type": "brew-cask",
      "package": "docker",
      "old_version": "4.25.0",
      "error": "Error: Cask 'docker' is already downloaded"
    },
    {
      "timestamp": "2024-11-14T12:37:00Z",
      "status": "skipped",
      "type": "brew",
      "package": "python",
      "old_version": "3.11.5",
      "new_version": "3.11.5"
    }
  ]
}
```

#### Summary File
A single summary file tracks all runs: `artifacts/update-summary.json`

```json
{
  "last_updated": "2024-11-14T12:45:30Z",
  "runs": [
    {
      "run_id": "20241114T123456Z",
      "start_time": "2024-11-14T12:34:56Z",
      "end_time": "2024-11-14T12:45:30Z",
      "summary": {
        "updated": 5,
        "refreshed": 2,
        "skipped": 10,
        "failed": 1,
        "total": 18
      },
      "report_file": "artifacts/update-report-20241114T123456Z.json"
    },
    {
      "run_id": "20241113T080000Z",
      "start_time": "2024-11-13T08:00:00Z",
      "end_time": "2024-11-13T08:12:45Z",
      "summary": {
        "updated": 3,
        "refreshed": 1,
        "skipped": 12,
        "failed": 0,
        "total": 16
      },
      "report_file": "artifacts/update-report-20241113T080000Z.json"
    }
  ]
}
```

## Report Fields

### Status Types
- **updated**: Package was successfully updated to a new version
- **refreshed**: Application was triggered to check for updates (for GUI apps)
- **skipped**: Package was already at the latest version or not installed
- **failed**: Update attempt failed with an error

### Result Fields
- `timestamp`: When this package was processed (ISO 8601 format)
- `status`: One of: updated, refreshed, skipped, failed
- `type`: Package manager type (brew, brew-cask, npm, pip, etc.)
- `package`: Package or application name
- `old_version`: Version before update (if available)
- `new_version`: Version after update (if available)
- `error`: Error message (only present for failed status)

## Benefits

### Easy Parsing
JSON format makes it simple to parse and analyze with any programming language:

```bash
# Get failed updates from latest run
jq '.results[] | select(.status == "failed")' artifacts/update-report-*.json | tail -1

# Count total updates across all runs
jq '[.runs[].summary.updated] | add' artifacts/update-summary.json

# Find packages that frequently fail
jq -r '.results[] | select(.status == "failed") | .package' artifacts/update-report-*.json | sort | uniq -c
```

### Historical Tracking
- Compare runs side-by-side
- Track update frequency for specific packages
- Identify recurring failures
- Monitor update patterns over time

### Better Debugging
- Exact error messages captured
- Timestamps for each operation
- Version changes clearly documented
- Easy to identify problematic packages

## Usage Examples

### View latest run summary
```bash
jq '.runs[-1]' artifacts/update-summary.json
```

### Get detailed results for a specific run
```bash
jq '.' artifacts/update-report-20241114T123456Z.json
```

### List all failed updates from latest run
```bash
jq -r '.results[] | select(.status == "failed") | "\(.package): \(.error)"' \
  $(ls -t artifacts/update-report-*.json | head -1)
```

### Compare last two runs
```bash
echo "Previous run:"
jq '.runs[-2].summary' artifacts/update-summary.json

echo "Latest run:"
jq '.runs[-1].summary' artifacts/update-summary.json
```
