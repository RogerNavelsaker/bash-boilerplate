# Bash Boilerplate

A production-ready Bash script framework synthesized from best practices.

## Files

| File | Description |
| :--- | :--- |
| `source.sh` | Core library containing 30+ production-grade utility functions. |
| `script.sh` | Sample script that sources `source.sh`; where your custom logic goes. |
| `template.sh` | A fully self-contained script (built from combining `source.sh` & `script.sh`). |
| `build.sh` | Helper script to generate `template.sh` from the other two. |

## Usage

1. **Local Development**: Work in `script.sh`. It automatically sources `source.sh` to provide all utilities.
2. **Build for Distribution**: Run `./build.sh` to generate `template.sh`.
3. **Deployment**: Ship `template.sh` as a single, zero-dependency file.

## Key Features

- **Safety First**: `set -euo pipefail` and Bash version checking.
- **Magic Variables**: `__dir`, `__file`, `__base`, and `__bin`.
- **Robust Logging**: Syslog levels, colors, and file logging support.
- **Utility Suite**: `slugify`, `backup`, `retry`, `confirm`, `spinner`, `dry-run`, and more.

## License

MIT
