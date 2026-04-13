#!/usr/bin/env bash

# Bash Boilerplate Core (core.sh)
# 
# Foundation engine for all scripts. Designed for sourcing or standalone build.
# Synthesized from ralish/bash-script-template and best practices.

# 1. Safety Flags
# DESC: Exit on error, unset variables, and pipe failures
set -euo pipefail
# DESC: Ensure traps are inherited by subshells and functions
set -o errtrace

# 2. Magic Variables
# DESC: Standard path variables for the current script
readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __base="$(basename "${__file}")"
readonly __bin="$(basename "$0")"
# DESC: The exact command string used to invoke the script
# shellcheck disable=SC2034,SC2015
readonly __invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"

# 3. Environment Variables & Defaults
LOG_LEVEL="${LOG_LEVEL:-6}"
LOG_FILE="${LOG_FILE:-}"
NO_COLOR="${NO_COLOR:-}"
DRY_RUN="${DRY_RUN:-0}"
__temp_files=()

# 4. Helper Detection

# DESC: Detect if the script is being sourced
# RETS: 0 if sourced, 1 if executed directly
function is_sourced() { [[ "${BASH_SOURCE[0]}" != "${0}" ]]; }

# DESC: Detect if stdout is a TTY
function is_tty() { [[ -t 1 ]]; }

# DESC: Detect if the current user is root
function is_root() { [[ "$(id -u)" -eq 0 ]]; }

# 5. Privilege Management

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# RETS: 0 if superuser credentials were acquired, otherwise 1
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

    if [[ -z ${superuser-} ]]; then
        return 1
    fi
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Command to execute
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

# DESC: Re-execute the current script with sudo if not already root
function sudo_escalate() {
    if ! is_root; then
        log INFO "Re-executing with sudo..."
        exec sudo "$0" "$@"
    fi
}

# DESC: Exit if the script is not running as root
function check_root() {
    is_root || die "This script must be run as root."
}

# 6. Cleanup & Traps

# DESC: Exit handler to clean up resources and log failures
function cleanup() {
    local -r exit_code=$?
    trap - SIGINT SIGTERM EXIT
    
    if [[ "${exit_code}" -ne 0 && "${exit_code}" -ne 130 ]]; then
        log ERROR "Script failed with exit code ${exit_code}" || true
    fi

    # Remove tracked temporary files
    for tmp in "${__temp_files[@]:-}"; do [[ -e "${tmp}" ]] && rm -rf "${tmp}" || true; done
    
    # Remove lockfile
    [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}" || true
    
    # Restore terminal colors
    [[ -n "${ta_none:-}" ]] && printf '%b' "${ta_none}" || true
    
    return "${exit_code}"
}
trap cleanup SIGINT SIGTERM EXIT

# 7. Logging & Colors

# DESC: Initialize color variables using tput
function colour_init() {
    # Always set ta_none as it's used in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"

    if [[ -z "${NO_COLOR}" ]] && [[ -t 2 ]] && [[ "${TERM:-}" != "dumb" ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"

        # Foreground codes
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

# DESC: Main logging function with Syslog-style levels
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

# 8. Utility Functions

# DESC: Exit with an error message
function die() { log ERROR "$1"; exit "${2:-1}"; }

# DESC: Check if required binaries exist
function check_dependencies() { for cmd in "$@"; do command -v "${cmd}" >/dev/null 2>&1 || die "Required dependency not found: ${cmd}"; done; }

# DESC: Check if an application is installed
function is_cmd() { command -v "${1}" >/dev/null 2>&1; }

# DESC: Prompt for user confirmation
function confirm() { local msg="${1:-Are you sure?}"; read -p "${msg} [y/N] " -n 1 -r; echo; [[ "${REPLY}" =~ ^[Yy]$ ]]; }

# DESC: Retry a command with exponential backoff
function retry() {
    local -r -i max_attempts="$1"; shift; local -r cmd="$@"; local -i attempt=1
    until eval "${cmd}"; do
        [[ "${attempt}" -eq "${max_attempts}" ]] && log ERROR "Failed after ${max_attempts} attempts: ${cmd}" && return 1
        local wait_time=$(( attempt * 2 )); log WARN "Retrying in ${wait_time}s... (Attempt ${attempt}/${max_attempts})"; sleep "${wait_time}"; (( attempt++ ))
    done
}

# DESC: Check if a directory, file, or variable is empty
function is_empty() { local -r p="${1:-}"; if [[ -d "${p}" ]]; then [[ -z "$(ls -A "${p}")" ]]; elif [[ -f "${p}" ]]; then [[ ! -s "${p}" ]]; else [[ -z "${p}" ]]; fi; }

# DESC: Validation helpers
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
function get_arch() { [[ "$(uname -s)" == "Darwin" ]] && readonly __arch="arm64" || readonly __arch="$(uname -m)"; }
function cpu_count() { nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1; }

# DESC: Version and Bash environment checks
function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }
function check_bash_version() {
    local -r min_version="${1:-4}"
    if [[ "${BASH_VERSINFO[0]}" -lt "${min_version}" ]]; then
        die "Requires Bash ${min_version}+. Current: ${BASH_VERSION}"
    fi
}

# DESC: Timer helpers
function timer_start() { __timer_start=$(date +%s); }
function timer_stop() { local d=$(( $(date +%s) - __timer_start )); echo "$((d / 60))m $((d % 60))s"; }

# DESC: Format helpers
function timestamp() { date +'%Y%m%d_%H%M%S'; }
function abs_path() {
    local p="${1}"
    if [[ -d "${p}" ]]; then (cd "${p}" && pwd); elif [[ -f "${p}" ]]; then echo "$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; else echo "${p}"; fi
}
function get_ext() { local f=$(basename -- "$1"); echo "${f##*.}"; }
function random_string() { local l="${1:-16}"; if is_cmd tr && [[ -r /dev/urandom ]]; then LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${l}"; echo; else printf "%s" "$RANDOM$RANDOM$RANDOM" | head -c "${l}"; echo; fi; }

# DESC: String manipulation
function to_lower() { echo "${1,,}"; }
function to_upper() { echo "${1^^}"; }
function trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; echo -n "${v}"; }
function join_by() { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }
function slugify() { echo "${1}" | tr '[:upper:]' '[:lower:]' | tr -sc '[:alnum:]' '-' | tr -s '-' | sed 's/^-//;s/-$//'; }

# DESC: UI and visual helpers
function indent() { local i="${1:-4}"; local s; printf -v s "%${i}s" ""; sed "s/^/${s}/"; }
function hr() { local c="${1:--}" w="${2:-80}" l; printf -v l "%${w}s" ""; echo "${l// /$c}"; }
function box() { local msg="$*"; local len=${#msg}; hr "-" $((len + 4)); echo "| ${msg} |"; hr "-" $((len + 4)); }

# DESC: Execution wrappers
function run() { if [[ "${DRY_RUN}" -eq 1 ]]; then log INFO "[DRY-RUN] $*"; else "$@"; fi; }
function quiet() { "$@" >/dev/null 2>&1; }

# DESC: Visual spinner for background processes
function spinner() {
    local pid=$1 delay=0.1 spin='|/-\'
    if [[ ! -t 1 ]]; then wait "$pid"; return $?; fi
    tput civis
    while kill -0 "$pid" 2>/dev/null; do local t=${spin#?}; printf " [%c]  " "$spin"; spin=$t${spin%"$t"}; sleep $delay; printf "\b\b\b\b\b\b"; done
    printf "    \b\b\b\b"; tput cnorm; wait "$pid"; return $?
}

# DESC: Filesystem helpers
function backup() { local f="$1"; [[ -f "$f" ]] || return 1; local b="${f}.$(timestamp).bak"; cp -p "$f" "$b"; echo "$b"; }
function mktemp_file() { local f=$(mktemp); __temp_files+=("${f}"); echo "${f}"; }
function mktemp_dir() { local d=$(mktemp -d); __temp_files+=("${d}"); echo "${d}"; }
function ensure_line() { local line="$1" file="$2"; [[ -f "${file}" ]] || touch "${file}"; grep -qF -- "${line}" "${file}" || echo "${line}" >> "${file}"; }

# DESC: Network and JSON helpers
function get_json_val() { if is_cmd jq; then echo "${1}" | jq -r "${2}"; else log WARN "jq not installed"; return 1; fi; }
function wait_for_url() { local u="${1}" t="${2:-30}" c=0; until quiet curl -s --head --request GET "${u}"; do sleep 1; ((c++)); [[ "${c}" -ge "${t}" ]] && return 1; done; return 0; }

# DESC: Mutex and environment helpers
function lock() {
    local l="${1:-/tmp/${__base}.lock}"; if [[ -e "${l}" ]]; then local p=$(cat "${l}"); kill -0 "${p}" 2>/dev/null && die "Already running (PID: ${p})"; fi
    echo "$$" > "${l}"; readonly __lockfile="${l}"
}
function unlock() { [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}"; }
function pause() { read -p "${1:-Press [Enter] to continue...}"; }
function load_env() {
    local f="${1:-.env}"; [[ -f "${f}" ]] || return 1
    while IFS='=' read -r k v || [[ -n "${k}" ]]; do [[ "${k}" =~ ^#.*$ || -z "${k}" ]] && continue; k=$(echo "${k}" | tr -d '[:space:]'); v=$(echo "${v}" | tr -d '[:space:]' | sed "s/^'//;s/'$//;s/^\"//;s/\"$//"); export "${k}=${v}"; done < "${f}"
}
