# Bash Boilerplate

A production-ready Bash script framework synthesized from best practices.

## Files

| File | Description |
| :--- | :--- |
| `core.sh` | Core library containing 30+ production-grade utility functions. |
| `main.sh` | Main script that sources `core.sh`; where your custom logic goes. |
| `standalone.sh` | A fully self-contained script (built from combining `core.sh` & `main.sh`). |
| `build.sh` | Helper script to generate `standalone.sh` from the other two. |

## Usage

1. **Local Development**: Work in `main.sh`. It automatically sources `core.sh` to provide all utilities.
2. **Build for Distribution**: Run `./build.sh` to generate `standalone.sh`.
3. **Deployment**: Ship `standalone.sh` as a single, zero-dependency file.

## Key Features

- **Safety First**: `set -euo pipefail` and Bash version checking.
- **Magic Variables**: `__dir`, `__file`, `__base`, and `__bin`.
- **Robust Logging**: Syslog levels, colors, and file logging support.
- **Utility Suite**: `slugify`, `backup`, `retry`, `confirm`, `spinner`, `dry-run`, and more.

## License

MIT
