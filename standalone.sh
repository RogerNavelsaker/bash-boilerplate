#!/usr/bin/env bash

# Bash Script Template (main.sh)
#
# This template uses core.sh for its foundational logic.
# For local development: ensure core.sh is in the same directory.
# For production: use build.sh to generate a standalone script.

set -euo pipefail
set -o errtrace

readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __base="$(basename "${__file}")"
readonly __bin="$(basename "$0")"
readonly __invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"

LOG_LEVEL="${LOG_LEVEL:-6}"
LOG_FILE="${LOG_FILE:-}"
NO_COLOR="${NO_COLOR:-}"
DRY_RUN="${DRY_RUN:-0}"
CRON="${CRON:-0}"
__temp_files=()

# DESC: Enable strict mode and safe defaults
# ARGS: None
# OUTS: None
# RETS: 0
function safe_mode() {
    set -euo pipefail
    set -o errtrace
    IFS=$'\n\t'
    set -f # Disable globbing by default
}

# DESC: Detect if the script is being sourced
# ARGS: None
# OUTS: None
# RETS: 0 if sourced, 1 if executed directly
function is_sourced() { [[ "${BASH_SOURCE[0]}" != "${0}" ]]; }

# DESC: Detect if stdout is a TTY
# ARGS: None
# OUTS: None
# RETS: 0 if TTY, 1 otherwise
function is_tty() { [[ -t 1 ]]; }

# DESC: Detect if the current user is root
# ARGS: None
# OUTS: None
# RETS: 0 if root, 1 otherwise
function is_root() { [[ "$(id -u)" -eq 0 ]]; }

# DESC: Validate superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
# RETS: 0 if superuser credentials were acquired, 1 otherwise
function check_superuser() {
    local superuser
    if [[ "$(id -u)" -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if is_cmd sudo; then
            if sudo -v >/dev/null 2>&1; then
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                [[ $test_euid -eq 0 ]] && superuser=true
            fi
        fi
    fi
    [[ -n "${superuser:-}" ]]
}

# DESC: Run requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Command to execute
# OUTS: Command output
# RETS: Command exit code
function run_as_root() {
    [[ $# -eq 0 ]] && die "Missing required argument to run_as_root()!"
    local skip_sudo=false
    if [[ ${1-} =~ ^0$ ]]; then
        skip_sudo=true
        shift
    fi
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif [[ "${skip_sudo}" == "false" ]]; then
        sudo -H -- "$@"
    else
        die "Unable to run requested command as root: $*"
    fi
}

# DESC: Re-execute current script with sudo if not already root
# ARGS: $@ (optional): Arguments to pass to re-executed script
# OUTS: Script output
# RETS: Script exit code
function sudo_escalate() {
    if ! is_root; then
        log INFO "Re-executing with sudo..."
        exec sudo "$0" "$@"
    fi
}

# DESC: Exit if script is not running as root
# ARGS: None
# OUTS: None
# RETS: None (exits on failure)
function check_root() {
    is_root || die "This script must be run as root."
}

# DESC: Handler for unexpected errors (backtrace)
# ARGS: $1 (required): line_no
#       $2 (required): fn_name
# OUTS: Error message to stderr
# RETS: Exits with original exit code
function error_trap() {
    local -r exit_code=$?
    local -r line_no=$1
    local -r fn_name=$2
    trap - ERR
    log ERROR "Error in ${__file} at line ${line_no} in function ${fn_name} (exit code: ${exit_code})"
    if [[ "${CRON}" -eq 1 && -n "${__cron_output:-}" ]]; then
        log ERROR "Cron output follows:"
        cat "${__cron_output}" >&2
    fi
    exit "${exit_code}"
}
trap 'error_trap "${LINENO}" "${FUNCNAME:-.}"' ERR

# DESC: Exit handler to clean up resources and log failures
# ARGS: None
# OUTS: None
# RETS: Original exit code
function cleanup() {
    local -r exit_code=$?
    trap - SIGINT SIGTERM EXIT
    if [[ "${exit_code}" -ne 0 && "${exit_code}" -ne 130 ]]; then
        log ERROR "Script failed with exit code ${exit_code}" || true
    fi
    for tmp in "${__temp_files[@]:-}"; do [[ -e "${tmp}" ]] && rm -rf "${tmp}" || true; done
    [[ -n "${__cron_output:-}" ]] && rm -f "${__cron_output}" || true
    [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}" || true
    [[ -n "${ta_none:-}" ]] && printf '%b' "${ta_none}" || true
    return "${exit_code}"
}
trap cleanup SIGINT SIGTERM EXIT

# DESC: Initialize color variables using tput
# ARGS: None
# OUTS: None
# RETS: 0
function colour_init() {
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
    if [[ -z "${NO_COLOR}" ]] && [[ -t 2 ]] && [[ "${TERM:-}" != "dumb" ]]; then
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
    else
        readonly ta_bold='' ta_uscore='' ta_blink='' ta_reverse=''
        readonly fg_black='' fg_blue='' fg_cyan='' fg_green='' fg_magenta='' fg_red='' fg_white='' fg_yellow=''
    fi
    return 0
}
colour_init

# DESC: Enable verbose debug mode with enhanced tracing
# ARGS: None
# OUTS: None
# RETS: None
function debug_mode() {
    set -o xtrace
    export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    LOG_LEVEL=7
}

# DESC: Main logging function with Syslog-style levels
# ARGS: $1 (required): level
#       $@ (required): message
# OUTS: Log message to stderr and optionally to LOG_FILE
# RETS: None
function log() {
    local level="${1:-INFO}"
    shift
    local msg="$*"
    local timestamp=$(date +'%Y-%m-%dT%H:%M:%S%z')
    local log_msg
    case "${level}" in
        EMERG) [[ "${LOG_LEVEL}" -ge 0 ]] && log_msg="${ta_bold}${fg_red}[${timestamp}] [EMERG] ${msg}${ta_none}" ;;
        ALERT) [[ "${LOG_LEVEL}" -ge 1 ]] && log_msg="${ta_bold}${fg_red}[${timestamp}] [ALERT] ${msg}${ta_none}" ;;
        CRIT)  [[ "${LOG_LEVEL}" -ge 2 ]] && log_msg="${ta_bold}${fg_red}[${timestamp}] [CRIT]  ${msg}${ta_none}" ;;
        ERROR) [[ "${LOG_LEVEL}" -ge 3 ]] && log_msg="${fg_red}[${timestamp}] [ERROR] ${msg}${ta_none}" ;;
        WARN)  [[ "${LOG_LEVEL}" -ge 4 ]] && log_msg="${fg_yellow}[${timestamp}] [WARN]  ${msg}${ta_none}" ;;
        NOTICE)[[ "${LOG_LEVEL}" -ge 5 ]] && log_msg="${fg_cyan}[${timestamp}] [NOTICE] ${msg}${ta_none}" ;;
        INFO)  [[ "${LOG_LEVEL}" -ge 6 ]] && log_msg="${fg_green}[${timestamp}] [INFO]  ${msg}${ta_none}" ;;
        DEBUG) [[ "${LOG_LEVEL}" -ge 7 ]] && log_msg="${fg_blue}[${timestamp}] [DEBUG] ${msg}${ta_none}" ;;
        *)     log_msg="[${timestamp}] [${level}] ${msg}" ;;
    esac
    if [[ -n "${log_msg:-}" ]]; then
        echo -e "${log_msg}" >&2
        [[ -n "${LOG_FILE}" ]] && echo -e "${log_msg}" | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}" || true
    fi
}

# DESC: Shorthand logging aliases
# ARGS: $@ (required): message
# OUTS: Log message
# RETS: None
function info() { log INFO "$@"; }
function warn() { log WARN "$@"; }
function error() { log ERROR "$@"; }
function debug() { log DEBUG "$@"; }
function notice() { log NOTICE "$@"; }

# DESC: Output to a named standard stream
# ARGS: $1 (required): stream (stdout or stderr)
#       $@ (required): message
# OUTS: Message to stream
# RETS: 0
function out() {
    local stream="$1"; shift
    case "${stream}" in
        stdout) echo -e "$*" >&1 ;;
        stderr) echo -e "$*" >&2 ;;
        *) die "Invalid stream: ${stream}. Use 'stdout' or 'stderr'." ;;
    esac
}

# DESC: Output to target file, overwriting content
# ARGS: $1 (required): target file path
#       $@ (required): message
# OUTS: Message to file
# RETS: 0
function overwrite() {
    local target="$1"; shift
    echo -e "$*" > "${target}"
}

# DESC: Output to target file, appending content
# ARGS: $1 (required): target file path
#       $@ (required): message
# OUTS: Message to file
# RETS: 0
function append() {
    local target="$1"; shift
    echo -e "$*" >> "${target}"
}

# DESC: Exit with an error message
# ARGS: $1 (required): message
#       $2 (optional): exit_code (default 1)
# OUTS: None
# RETS: None (exits)
function die() { log ERROR "$1"; exit "${2:-1}"; }

# DESC: Check if required binaries exist
# ARGS: $@ (required): binary names
# OUTS: None
# RETS: None (dies on missing dependency)
function check_dependencies() { for cmd in "$@"; do command -v "${cmd}" >/dev/null 2>&1 || die "Required dependency not found: ${cmd}"; done; }

# DESC: Check if an application is installed
# ARGS: $1 (required): command name
# OUTS: None
# RETS: 0 if installed, 1 otherwise
function is_cmd() { command -v "${1}" >/dev/null 2>&1; }

# DESC: Prompt for user confirmation
# ARGS: $1 (optional): message
# OUTS: Prompt to stdout
# RETS: 0 if confirmed, 1 otherwise
function confirm() { local msg="${1:-Are you sure?}"; read -p "${msg} [y/N] " -n 1 -r; echo; [[ "${REPLY}" =~ ^[Yy]$ ]]; }

# DESC: Retry a command with exponential backoff
# ARGS: $1 (required): max_attempts
#       $@ (required): command
# OUTS: Command output
# RETS: 0 on success, 1 otherwise
function retry() {
    local -r -i max_attempts="$1"; shift; local -r cmd="$@"; local -i attempt=1
    until eval "${cmd}"; do
        [[ "${attempt}" -eq "${max_attempts}" ]] && log ERROR "Failed after ${max_attempts} attempts: ${cmd}" && return 1
        local wait_time=$(( attempt * 2 )); log WARN "Retrying in ${wait_time}s... (Attempt ${attempt}/${max_attempts})"; sleep "${wait_time}"; (( attempt++ ))
    done
}

# DESC: Check if a directory, file, or variable is empty
# ARGS: $1 (required): path or variable
# OUTS: None
# RETS: 0 if empty, 1 otherwise
function is_empty() {
    local -r p="${1:-}"
    if [[ -d "${p}" ]]; then
        local -a files
        shopt -s nullglob
        files=("${p}"/* "${p}"/.*)
        shopt -u nullglob
        # Check for count <= 2 (just . and ..)
        [[ ${#files[@]} -le 2 ]]
    elif [[ -f "${p}" ]]; then
        [[ ! -s "${p}" ]]
    else
        [[ -z "${p}" ]]
    fi
}

# DESC: Validation helpers
# ARGS: $1 (required): value
# OUTS: None
# RETS: 0 if valid, 1 otherwise
function is_int() { [[ "${1}" =~ ^-?[0-9]+$ ]]; }
function is_alphanumeric() { [[ "${1}" =~ ^[a-zA-Z0-9]+$ ]]; }
function is_function() { [[ -n "${1:-}" ]] && [[ "$(type -t "${1}")" == "function" ]]; }
function is_ssh() { [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; }
function is_online() { for h in "8.8.8.8" "1.1.1.1" "google.com"; do ping -c 1 -W 1 "$h" >/dev/null 2>&1 && return 0; done; return 1; }
function is_mac() { [[ "$(uname -s)" == "Darwin" ]]; }
function is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
function is_container() { [[ -f /.dockerenv ]] || grep -qE "docker|lxc|containerd" /proc/1/cgroup 2>/dev/null || return 1; }
function is_git_repo() { is_cmd git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# DESC: System information helpers
# ARGS: None
# OUTS: __arch or core count
# RETS: 0
function get_arch() { [[ "$(uname -s)" == "Darwin" ]] && readonly __arch="arm64" || readonly __arch="$(uname -m)"; }
function cpu_count() { nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1; }

# DESC: Version and Bash environment checks
# ARGS: $1 (optional): min_version (default 4)
# OUTS: None
# RETS: 0
function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }
function check_bash_version() {
    local -r min_version="${1:-4}"
    if [[ "${BASH_VERSINFO[0]}" -lt "${min_version}" ]]; then
        die "Requires Bash ${min_version}+. Current: ${BASH_VERSION}"
    fi
}

# DESC: Timer helpers
# ARGS: None
# OUTS: Duration to stdout
# RETS: 0
function timer_start() { __timer_start=$(date +%s); }
function timer_stop() { local d=$(( $(date +%s) - __timer_start )); echo "$((d / 60))m $((d % 60))s"; }

# DESC: Format helpers
# ARGS: $1 (optional): length or path
# OUTS: Formatted string to stdout
# RETS: 0
function timestamp() { date +'%Y%m%d_%H%M%S'; }
function abs_path() {
    local p="${1}"
    if [[ -d "${p}" ]]; then (cd "${p}" && pwd); elif [[ -f "${p}" ]]; then echo "$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; else echo "${p}"; fi
}
function get_ext() { local f=$(basename -- "$1"); echo "${f##*.}"; }
function random_string() {
    local l="${1:-16}"
    if is_cmd tr && [[ -r /dev/urandom ]]; then LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${l}"; echo; else printf "%s" "$RANDOM$RANDOM$RANDOM" | head -c "${l}"; echo; fi
}

# DESC: String manipulation
# ARGS: $1 (required): string
# OUTS: Modified string to stdout
# RETS: 0
function to_lower() { echo "${1,,}"; }
function to_upper() { echo "${1^^}"; }
function trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; echo -n "${v}"; }
function join_by() { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }
function slugify() { echo "${1}" | tr '[:upper:]' '[:lower:]' | tr -sc '[:alnum:]' '-' | tr -s '-' | sed 's/^-//;s/-$//'; }

# DESC: UI and visual helpers
# ARGS: $1 (optional): char, length or message
# OUTS: Visual element to stdout
# RETS: 0
function indent() { local i="${1:-4}"; local s; printf -v s "%${i}s" ""; sed "s/^/${s}/"; }
function hr() { local c="${1:--}" w="${2:-80}" l; printf -v l "%${w}s" ""; echo "${l// /$c}"; }
function box() { local msg="$*"; local len=${#msg}; hr "-" $((len + 4)); echo "| ${msg} |" ; hr "-" $((len + 4)); }

# DESC: Execution wrappers
# ARGS: $@ (required): command
# OUTS: Command output
# RETS: Command exit code
function run() { if [[ "${DRY_RUN}" -eq 1 ]]; then log INFO "[DRY-RUN] $*"; else "$@"; fi; }
function quiet() { "$@" >/dev/null 2>&1; }

# DESC: Visual spinner for background processes
# ARGS: $1 (required): pid
# OUTS: Spinner to stdout
# RETS: 0
function spinner() {
    local pid=$1 delay=0.1 spin='|/-\'
    if [[ ! -t 1 ]]; then wait "$pid"; return $?; fi
    tput civis
    while kill -0 "$pid" 2>/dev/null; do local t=${spin#?}; printf " [%c]  " "$spin"; spin=$t${spin%"$t"}; sleep $delay; printf "\b\b\b\b\b\b"; done
    printf "    \b\b\b\b"; tput cnorm; wait "$pid"; return $?
}

# DESC: Filesystem helpers
# ARGS: $1 (required): file or line
# OUTS: Modified file
# RETS: 0
function backup() { local f="$1"; [[ -f "$f" ]] || return 1; local b="${f}.$(timestamp).bak"; cp -p "$f" "$b"; echo "$b"; }
function mktemp_file() { local f=$(mktemp); __temp_files+=("${f}"); echo "${f}"; }
function mktemp_dir() { local d=$(mktemp -d); __temp_files+=("${d}"); echo "${d}"; }
function ensure_line() { local line="$1" file="$2"; [[ -f "${file}" ]] || touch "${file}"; grep -qF -- "${line}" "${file}" || echo "${line}" >> "${file}"; }

# DESC: Network and JSON helpers
# ARGS: $1 (required): json or url
# OUTS: Extracted value or status
# RETS: 0
function get_json_val() { if is_cmd jq; then echo "${1}" | jq -r "${2}"; else log WARN "jq not installed"; return 1; fi; }
function wait_for_url() { local u="${1}" t="${2:-30}" c=0; until quiet curl -s --head --request GET "${u}"; do sleep 1; ((c++)); [[ "${c}" -ge "${t}" ]] && return 1; done; return 0; }

# DESC: Acquire script lock with scope (user or system)
# ARGS: $1 (optional): scope
# OUTS: None
# RETS: 0
function lock() {
    local scope="${1:-system}"
    local l
    if [[ "${scope}" == "user" ]]; then
        l="/tmp/${__base}.${UID}.lock"
    else
        l="/tmp/${__base}.lock"
    fi
    if [[ -e "${l}" ]]; then
        local p=$(cat "${l}")
        kill -0 "${p}" 2>/dev/null && die "Already running (PID: ${p})"
    fi
    echo "$$" > "${l}"
    readonly __lockfile="${l}"
}

# DESC: Unlock script
# ARGS: None
# OUTS: None
# RETS: 0
function unlock() { [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}"; }

# DESC: Wait for user input
# ARGS: $1 (optional): message
# OUTS: Message to stdout
# RETS: 0
function pause() { read -p "${1:-Press [Enter] to continue...}"; }

# DESC: Load environment variables from file
# ARGS: $1 (optional): env_file
# OUTS: Exported variables
# RETS: 0
function load_env() {
    local f="${1:-.env}"; [[ -f "${f}" ]] || return 1
    while IFS='=' read -r k v || [[ -n "${k}" ]]; do
        [[ "${k}" =~ ^#.*$ || -z "${k}" ]] && continue
        # Pure Bash trim
        k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
        v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
        # Strip quotes
        v="${v#[\"\']}"; v="${v%[\"\']}"
        export "${k}=${v}"
    done < "${f}"
}

# DESC: Initialize Cron mode (redirects output to temp file)
# ARGS: None
# OUTS: Redirected file
# RETS: 0
function cron_init() {
    if [[ "${CRON}" -eq 1 ]]; then
        __cron_output=$(mktemp_file)
        readonly __cron_output
        exec 3>&1 4>&2 1> "${__cron_output}" 2>&1
    fi
}

# 8. Argument Parsing
usage() {
    cat <<EOF
Usage: ${__bin} [OPTIONS] [ARGUMENTS]

A robust script based on the bash-boilerplate template.

Options:
    -h, --help      Display this help message
    -v, --verbose   Enable verbose logging (LOG_LEVEL=7)
    -d, --dry-run   Simulation mode (don't execute commands)
    --debug         Enable xtrace debugging
    --cron          Enable cron mode (redirect output)
    -f, --flag      An example flag
    -o, --option    An example option with a value

Example:
    ${__bin} --verbose --option "Hello World"
EOF
}

parse_params() {
    flag=0
    option_val=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) LOG_LEVEL=7; shift ;;
            -d|--dry-run) DRY_RUN=1; shift ;;
            --debug)      debug_mode; shift ;;
            --cron)       CRON=1; shift ;;
            -f|--flag)    flag=1; shift ;;
            -o|--option)  [[ -z "${2:-}" || "${2:-}" == -* ]] && die "Option $1 requires a value"; option_val="$2"; shift 2 ;;
            --)           shift; break ;;
            -?*)          die "Unknown option: $1" ;;
            *)            break ;;
        esac
    done
    args=("$@")
}

# 9. Main Logic
function print_telemetry() {
    local ms=$1 tokens=$2 turns=$3 success=$4
    local status="${ta_bold}${fg_red}FAILED${ta_none}"
    [[ "${success}" == "1" ]] && status="${ta_bold}${fg_green}SUCCESS${ta_none}"
    info "  [TELEMETRY] Status: ${status} | Time: $((ms/1000))s | Tokens: ${tokens} | Turns: ${turns}"
}

main() {
    safe_mode
    check_bash_version 4
    parse_params "$@"
    cron_init

    log INFO "Script started: ${__base}"
    log DEBUG "Invocation: ${__invocation}"
    
    # Example validation
    [[ -z "${option_val}" && ${flag} -eq 0 ]] && { usage; exit "${E_USAGE}"; }

    log INFO "Completed successfully!"
    return "${E_SUCCESS}"
}

# 10. Sourcing Protection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
