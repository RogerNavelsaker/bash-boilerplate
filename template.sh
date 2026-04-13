#!/usr/bin/env bash

# Bash Script Template
# Synthesized from:
# - https://github.com/ralish/bash-script-template
# - https://github.com/kvz/bash3boilerplate
# - Best practices for modern Bash

# 1. Safety Flags
# -e: Exit on error
# -u: Exit on unset variables
# -o pipefail: Pipeline fails if any command fails
set -euo pipefail

# 2. Magic Variables
# __dir: The directory where the script resides
# __file: The absolute path to the script
# __base: The filename of the script (without path)
# __bin: The name of the binary used to invoke the script
readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __base="$(basename "${__file}")"
readonly __bin="$(basename "$0")"

# 3. Environment Variables & Defaults
# LOG_LEVEL: 0 (EMERG) to 7 (DEBUG). Default: 6 (INFO)
LOG_LEVEL="${LOG_LEVEL:-6}"
NO_COLOR="${NO_COLOR:-}"

# 4. Cleanup & Traps
# cleanup() is called on script exit or interruption
cleanup() {
    trap - SIGINT SIGTERM EXIT
    # Add your cleanup logic here (e.g., removing temporary files)
    # [[ -d "${tmp_dir:-}" ]] && rm -rf "${tmp_dir}"
}
trap cleanup SIGINT SIGTERM EXIT

# 5. Logging System
# Usage: log <LEVEL> <MESSAGE>
# LEVELS: DEBUG, INFO, WARN, ERROR
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        readonly CLR_RED='\033[0;31m'
        readonly CLR_GREEN='\033[0;32m'
        readonly CLR_YELLOW='\033[0;33m'
        readonly CLR_BLUE='\033[0;34m'
        readonly CLR_RESET='\033[0m'
    else
        readonly CLR_RED=''
        readonly CLR_GREEN=''
        readonly CLR_YELLOW=''
        readonly CLR_BLUE=''
        readonly CLR_RESET=''
    fi
}
setup_colors

log() {
    local level="${1:-INFO}"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date +'%Y-%m-%dT%H:%M:%S%z')

    case "${level}" in
        DEBUG) [[ "${LOG_LEVEL}" -ge 7 ]] && echo -e "${CLR_BLUE}[${timestamp}] [DEBUG] ${msg}${CLR_RESET}" >&2 ;;
        INFO)  [[ "${LOG_LEVEL}" -ge 6 ]] && echo -e "${CLR_GREEN}[${timestamp}] [INFO]  ${msg}${CLR_RESET}" >&2 ;;
        WARN)  [[ "${LOG_LEVEL}" -ge 4 ]] && echo -e "${CLR_YELLOW}[${timestamp}] [WARN]  ${msg}${CLR_RESET}" >&2 ;;
        ERROR) [[ "${LOG_LEVEL}" -ge 3 ]] && echo -e "${CLR_RED}[${timestamp}] [ERROR] ${msg}${CLR_RESET}" >&2 ;;
        *)     echo -e "[${timestamp}] [${level}] ${msg}" >&2 ;;
    esac
}

# 6. Utility Functions
die() {
    local msg="$1"
    local code="${2:-1}"
    log ERROR "${msg}"
    exit "${code}"
}

check_dependencies() {
    for cmd in "$@"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            die "Required dependency not found: ${cmd}"
        fi
    done
}

# 7. Argument Parsing
usage() {
    cat <<EOF
Usage: ${__bin} [OPTIONS] [ARGUMENTS]

A robust bash script boilerplate.

Options:
    -h, --help      Display this help message
    -v, --verbose   Enable debug logging (LOG_LEVEL=7)
    -f, --flag      An example flag
    -o, --option    An example option with a value

Example:
    ${__bin} --verbose --option "Hello World"
EOF
}

parse_params() {
    # Default values for arguments
    flag=0
    option_val=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                LOG_LEVEL=7
                shift
                ;;
            -f|--flag)
                flag=1
                shift
                ;;
            -o|--option)
                if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
                    die "Option $1 requires a value"
                fi
                option_val="$2"
                shift 2
                ;;
            --) # End of all options
                shift
                break
                ;;
            -?*)
                die "Unknown option: $1"
                ;;
            *)
                break
                ;;
        esac
    done

    args=("$@")
    return 0
}

# 8. Main Logic
main() {
    parse_params "$@"

    log INFO "Starting ${__base}..."
    log DEBUG "Command line arguments: ${args[*]:-}"

    # Example: check for dependencies
    # check_dependencies git curl

    if [[ "${flag}" -eq 1 ]]; then
        log INFO "Flag -f/--flag was set"
    fi

    if [[ -n "${option_val}" ]]; then
        log INFO "Option -o/--option set to: ${option_val}"
    fi

    log INFO "Completed successfully!"
}

# 9. Sourcing Protection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
