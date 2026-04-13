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

# 4. Helper Detection
is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

is_tty() {
    [[ -t 1 ]]
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

# 5. Cleanup & Traps
# cleanup() is called on script exit or interruption
cleanup() {
    local -r exit_code=$?
    trap - SIGINT SIGTERM EXIT
    
    if [[ "${exit_code}" -ne 0 && "${exit_code}" -ne 130 ]]; then
        log ERROR "Script failed with exit code ${exit_code}"
    fi
    
    # Add your cleanup logic here (e.g., removing temporary files)
}
trap cleanup SIGINT SIGTERM EXIT

# 6. Logging & Colors
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        # Standard Colors
        readonly CLR_BLACK='\033[0;30m'
        readonly CLR_RED='\033[0;31m'
        readonly CLR_GREEN='\033[0;32m'
        readonly CLR_YELLOW='\033[0;33m'
        readonly CLR_BLUE='\033[0;34m'
        readonly CLR_MAGENTA='\033[0;35m'
        readonly CLR_CYAN='\033[0;36m'
        readonly CLR_WHITE='\033[0;37m'
        
        # Bold Colors
        readonly CLR_B_BLACK='\033[1;30m'
        readonly CLR_B_RED='\033[1;31m'
        readonly CLR_B_GREEN='\033[1;32m'
        readonly CLR_B_YELLOW='\033[1;33m'
        readonly CLR_B_BLUE='\033[1;34m'
        readonly CLR_B_MAGENTA='\033[1;35m'
        readonly CLR_B_CYAN='\033[1;36m'
        readonly CLR_B_WHITE='\033[1;37m'
        
        # Formatting
        readonly CLR_BOLD='\033[1m'
        readonly CLR_DIM='\033[2m'
        readonly CLR_UNDERLINE='\033[4m'
        readonly CLR_RESET='\033[0m'
    else
        readonly CLR_BLACK='' CLR_RED='' CLR_GREEN='' CLR_YELLOW='' CLR_BLUE='' CLR_MAGENTA='' CLR_CYAN='' CLR_WHITE=''
        readonly CLR_B_BLACK='' CLR_B_RED='' CLR_B_GREEN='' CLR_B_YELLOW='' CLR_B_BLUE='' CLR_B_MAGENTA='' CLR_B_CYAN='' CLR_B_WHITE=''
        readonly CLR_BOLD='' CLR_DIM='' CLR_UNDERLINE='' CLR_RESET=''
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
        EMERG) [[ "${LOG_LEVEL}" -ge 0 ]] && echo -e "${CLR_B_RED}[${timestamp}] [EMERG] ${msg}${CLR_RESET}" >&2 ;;
        ALERT) [[ "${LOG_LEVEL}" -ge 1 ]] && echo -e "${CLR_B_RED}[${timestamp}] [ALERT] ${msg}${CLR_RESET}" >&2 ;;
        CRIT)  [[ "${LOG_LEVEL}" -ge 2 ]] && echo -e "${CLR_B_RED}[${timestamp}] [CRIT]  ${msg}${CLR_RESET}" >&2 ;;
        ERROR) [[ "${LOG_LEVEL}" -ge 3 ]] && echo -e "${CLR_RED}[${timestamp}] [ERROR] ${msg}${CLR_RESET}" >&2 ;;
        WARN)  [[ "${LOG_LEVEL}" -ge 4 ]] && echo -e "${CLR_YELLOW}[${timestamp}] [WARN]  ${msg}${CLR_RESET}" >&2 ;;
        NOTICE)[[ "${LOG_LEVEL}" -ge 5 ]] && echo -e "${CLR_CYAN}[${timestamp}] [NOTICE] ${msg}${CLR_RESET}" >&2 ;;
        INFO)  [[ "${LOG_LEVEL}" -ge 6 ]] && echo -e "${CLR_GREEN}[${timestamp}] [INFO]  ${msg}${CLR_RESET}" >&2 ;;
        DEBUG) [[ "${LOG_LEVEL}" -ge 7 ]] && echo -e "${CLR_BLUE}[${timestamp}] [DEBUG] ${msg}${CLR_RESET}" >&2 ;;
        *)     echo -e "[${timestamp}] [${level}] ${msg}" >&2 ;;
    esac
}

# 7. Utility Functions
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

confirm() {
    local msg="${1:-Are you sure?}"
    read -p "${msg} [y/N] " -n 1 -r
    echo
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        return 1
    fi
}

retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt=1

    until eval "${cmd}"; do
        if (( attempt == max_attempts )); then
            log ERROR "Command failed after ${max_attempts} attempts: ${cmd}"
            return 1
        fi

        local wait_time=$(( attempt * 2 ))
        log WARN "Command failed. Retrying in ${wait_time}s... (Attempt ${attempt}/${max_attempts})"
        sleep "${wait_time}"
        (( attempt++ ))
    done
}

is_empty() {
    local -r path="${1:-}"
    if [[ -d "${path}" ]]; then
        [[ -z "$(ls -A "${path}")" ]]
    elif [[ -f "${path}" ]]; then
        [[ ! -s "${path}" ]]
    else
        [[ -z "${path}" ]]
    fi
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

    # Example: check if a directory/file/variable is empty
    # if is_empty "/tmp/test"; then
    #     log INFO "Target is empty"
    # fi

    # Example: confirm an action
    # if confirm "Do you want to proceed?"; then
    #     log INFO "User confirmed!"
    # else
    #     log INFO "User cancelled"
    # fi

    # Example: retry a command
    # retry 3 "ls -l /nonexistent" || true

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
