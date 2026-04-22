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

- **Safety First**: `safe_mode` (strict mode, IFS, and globbing protection) and Bash version checking.
- **Robust Error Handling**: Stack traces on failure and standard exit codes (sysexits.h).
- **Magic Variables**: `__dir`, `__file`, `__base`, and `__bin`.
- **High Performance**: Pure Bash implementations of utilities like `timestamp` and `is_empty` to reduce external dependencies.
- **Robust Logging**: Syslog levels, colors, and file logging support.
- **Utility Suite**: `slugify`, `backup`, `retry`, `confirm`, `spinner`, `dry-run`, and more.

## Inspiration
- [ralish/bash-script-template](https://github.com/ralish/bash-script-template)
- [kvz/bash3boilerplate](https://github.com/kvz/bash3boilerplate)
- [modernish/modernish](https://github.com/modernish/modernish)
- [jmcantrell/bashful](https://github.com/jmcantrell/bashful)
- [zombieleet/bashify](https://github.com/zombieleet/bashify)
- [dylanaraps/pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)
- [awesome-lists/awesome-bash](https://github.com/awesome-lists/awesome-bash)

## Testing
- [koalaman/shellcheck](https://github.com/koalaman/shellcheck)
- [bats-core/bats-core](https://github.com/bats-core/bats-core)
- [anordal/shellharden](https://github.com/anordal/shellharden)


## License

MIT
