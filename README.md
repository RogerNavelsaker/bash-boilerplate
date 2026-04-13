# Bash Boilerplate

A high-quality, production-ready Bash script boilerplate synthesized from industry-leading templates ([ralish/bash-script-template](https://github.com/ralish/bash-script-template) and [kvz/bash3boilerplate](https://github.com/kvz/bash3boilerplate)).

## Key Features

- **Safety First**: Uses `set -euo pipefail` to ensure scripts fail fast and predictably.
- **Magic Variables**: Automatically provides `__dir`, `__file`, `__base`, and `__bin` for reliable pathing.
- **Robust Logging**: Includes a `log()` function with Syslog-style levels (`DEBUG`, `INFO`, `WARN`, `ERROR`) and automatic color detection.
- **Argument Parsing**: Handles both short (`-f`) and long (`--flag`) options with an automated help display.
- **Cleanup Handlers**: Built-in `trap` support for `EXIT`, `SIGINT`, and `SIGTERM`.
- **Dependency Checks**: Easy utility to verify required binaries before execution.
- **Sourcing Protection**: Detects if the script is being sourced or executed directly.

## Usage

1. Copy `template.sh` to your project.
2. Rename it (e.g., `my-script.sh`).
3. Add your logic in the `main()` function.
4. Define your parameters in `parse_params()`.

## License

MIT
