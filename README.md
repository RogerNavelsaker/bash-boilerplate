# Bash Boilerplate

A high-quality, production-ready Bash script boilerplate synthesized from industry-leading templates ([ralish/bash-script-template](https://github.com/ralish/bash-script-template), [kvz/bash3boilerplate](https://github.com/kvz/bash3boilerplate), and [xwmx/bash-boilerplate](https://github.com/xwmx/bash-boilerplate)).

## Key Features

- **Safety First**: Uses `set -euo pipefail` and `check_bash_version 4`.
- **Magic Variables**: Automatically provides `__dir`, `__file`, `__base`, and `__bin`.
- **Robust Logging**: Syslog-style levels (`EMERG` to `DEBUG`) with colors and `LOG_FILE` support.
- **Dry Run Support**: Built-in `--dry-run` flag and `run()` wrapper.
- **Automatic Cleanup**: Tracks and deletes temporary files/dirs created via `mktemp_file` or `mktemp_dir`.
- **Environment Aware**: Detects `is_container`, `is_ssh`, `is_git_repo`, `is_mac`, and `is_linux`.
- **Utility Suite**: Includes `slugify`, `backup`, `retry`, `confirm`, `spinner`, `wait_for_url`, and more.

## Usage Options

You have two ways to use this boilerplate depending on your project size:

### 1. Standalone (All-in-One)
Best for small scripts or when you need to distribute a single file.

- **File**: `main.sh`
- **Action**: Copy `main.sh` to your project and rename it.

### 2. Modular (Library-based)
Best for larger projects with multiple scripts that should share the same core utilities.

- **Files**: `modular-script.sh` and `lib/core.sh`
- **Action**: Copy the `lib/` directory and use `modular-script.sh` as your template.
- **Benefit**: Update the library once to benefit all scripts.

## License

MIT
