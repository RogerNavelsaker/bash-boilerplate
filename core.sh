#!/usr/bin/env bash

# Bash Boilerplate Core (core.sh)
# 
# This file contains the foundational engine for all scripts.
# It can be used as a standalone library (sourced) or as part of a build.

# 1. Safety Flags
set -euo pipefail

# 2. Magic Variables
readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __base="$(basename "${__file}")"
readonly __bin="$(basename "$0")"

# 3. Environment Variables & Defaults
LOG_LEVEL="${LOG_LEVEL:-6}"
LOG_FILE="${LOG_FILE:-}"
NO_COLOR="${NO_COLOR:-}"
DRY_RUN="${DRY_RUN:-0}"
__temp_files=()

# 4. Helper Detection
is_sourced() { [[ "${BASH_SOURCE[0]}" != "${0}" ]]; }
is_tty() { [[ -t 1 ]]; }
is_root() { [[ "$(id -u)" -eq 0 ]]; }

# 5. Cleanup & Traps
cleanup() {
    local -r exit_code=$?
    trap - SIGINT SIGTERM EXIT
    if [[ "${exit_code}" -ne 0 && "${exit_code}" -ne 130 ]]; then
        log ERROR "Script failed with exit code ${exit_code}" || true
    fi
    for tmp in "${__temp_files[@]:-}"; do [[ -e "${tmp}" ]] && rm -rf "${tmp}" || true; done
    [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}" || true
    return "${exit_code}"
}
trap cleanup SIGINT SIGTERM EXIT

# 6. Logging & Colors
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        readonly CLR_BLACK='\033[0;30m' CLR_RED='\033[0;31m' CLR_GREEN='\033[0;32m' CLR_YELLOW='\033[0;33m' CLR_BLUE='\033[0;34m' CLR_MAGENTA='\033[0;35m' CLR_CYAN='\033[0;36m' CLR_WHITE='\033[0;37m'
        readonly CLR_B_BLACK='\033[1;30m' CLR_B_RED='\033[1;31m' CLR_B_GREEN='\033[1;32m' CLR_B_YELLOW='\033[1;33m' CLR_B_BLUE='\033[1;34m' CLR_B_MAGENTA='\033[1;35m' CLR_B_CYAN='\033[1;36m' CLR_B_WHITE='\033[1;37m'
        readonly CLR_BOLD='\033[1m' CLR_DIM='\033[2m' CLR_UNDERLINE='\033[4m' CLR_RESET='\033[0m'
    else
        readonly CLR_BLACK='' CLR_RED='' CLR_GREEN='' CLR_YELLOW='' CLR_BLUE='' CLR_MAGENTA='' CLR_CYAN='' CLR_WHITE=''
        readonly CLR_B_BLACK='' CLR_B_RED='' CLR_B_GREEN='' CLR_B_YELLOW='' CLR_B_BLUE='' CLR_B_MAGENTA='' CLR_B_CYAN='' CLR_B_WHITE=''
        readonly CLR_BOLD='' CLR_DIM='' CLR_UNDERLINE='' CLR_RESET=''
    fi
    return 0
}
setup_colors

log() {
    local level="${1:-INFO}"
    shift
    local msg="$*"
    local timestamp=$(date +'%Y-%m-%dT%H:%M:%S%z')
    local log_msg
    case "${level}" in
        EMERG) [[ "${LOG_LEVEL}" -ge 0 ]] && log_msg="${CLR_B_RED}[${timestamp}] [EMERG] ${msg}${CLR_RESET}" ;;
        ALERT) [[ "${LOG_LEVEL}" -ge 1 ]] && log_msg="${CLR_B_RED}[${timestamp}] [ALERT] ${msg}${CLR_RESET}" ;;
        CRIT)  [[ "${LOG_LEVEL}" -ge 2 ]] && log_msg="${CLR_B_RED}[${timestamp}] [CRIT]  ${msg}${CLR_RESET}" ;;
        ERROR) [[ "${LOG_LEVEL}" -ge 3 ]] && log_msg="${CLR_RED}[${timestamp}] [ERROR] ${msg}${CLR_RESET}" ;;
        WARN)  [[ "${LOG_LEVEL}" -ge 4 ]] && log_msg="${CLR_YELLOW}[${timestamp}] [WARN]  ${msg}${CLR_RESET}" ;;
        NOTICE)[[ "${LOG_LEVEL}" -ge 5 ]] && log_msg="${CLR_CYAN}[${timestamp}] [NOTICE] ${msg}${CLR_RESET}" ;;
        INFO)  [[ "${LOG_LEVEL}" -ge 6 ]] && log_msg="${CLR_GREEN}[${timestamp}] [INFO]  ${msg}${CLR_RESET}" ;;
        DEBUG) [[ "${LOG_LEVEL}" -ge 7 ]] && log_msg="${CLR_BLUE}[${timestamp}] [DEBUG] ${msg}${CLR_RESET}" ;;
        *)     log_msg="[${timestamp}] [${level}] ${msg}" ;;
    esac
    if [[ -n "${log_msg:-}" ]]; then
        echo -e "${log_msg}" >&2
        [[ -n "${LOG_FILE}" ]] && echo -e "${log_msg}" | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}" || true
    fi
}

# 7. Utility Functions
die() { log ERROR "$1"; exit "${2:-1}"; }
check_dependencies() { for cmd in "$@"; do command -v "${cmd}" >/dev/null 2>&1 || die "Required dependency not found: ${cmd}"; done; }
is_cmd() { command -v "${1}" >/dev/null 2>&1; }
confirm() { local msg="${1:-Are you sure?}"; read -p "${msg} [y/N] " -n 1 -r; echo; [[ "${REPLY}" =~ ^[Yy]$ ]]; }
retry() {
    local -r -i max_attempts="$1"; shift; local -r cmd="$@"; local -i attempt=1
    until eval "${cmd}"; do
        [[ "${attempt}" -eq "${max_attempts}" ]] && log ERROR "Failed after ${max_attempts} attempts: ${cmd}" && return 1
        local wait_time=$(( attempt * 2 )); log WARN "Retrying in ${wait_time}s... (Attempt ${attempt}/${max_attempts})"; sleep "${wait_time}"; (( attempt++ ))
    done
}
is_empty() { local -r p="${1:-}"; if [[ -d "${p}" ]]; then [[ -z "$(ls -A "${p}")" ]]; elif [[ -f "${p}" ]]; then [[ ! -s "${p}" ]]; else [[ -z "${p}" ]]; fi; }
is_int() { [[ "${1}" =~ ^-?[0-9]+$ ]]; }
is_alphanumeric() { [[ "${1}" =~ ^[a-zA-Z0-9]+$ ]]; }
is_function() { [[ -n "${1:-}" ]] && [[ "$(type -t "${1}")" == "function" ]]; }
is_ssh() { [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; }
is_online() { for h in "8.8.8.8" "1.1.1.1" "google.com"; do ping -c 1 -W 1 "$h" >/dev/null 2>&1 && return 0; done; return 1; }
is_mac() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
is_container() { [[ -f /.dockerenv ]] || grep -qE "docker|lxc|containerd" /proc/1/cgroup 2>/dev/null || return 1; }
is_git_repo() { is_cmd git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }
check_bash_version() {
    local -r min_version="${1:-4}"
    if [[ "${BASH_VERSINFO[0]}" -lt "${min_version}" ]]; then
        die "Requires Bash ${min_version}+. Current: ${BASH_VERSION}"
    fi
}
timer_start() { __timer_start=$(date +%s); }
timer_stop() { local d=$(( $(date +%s) - __timer_start )); echo "$((d / 60))m $((d % 60))s"; }
timestamp() { date +'%Y%m%d_%H%M%S'; }
abs_path() {
    local p="${1}"
    if [[ -d "${p}" ]]; then (cd "${p}" && pwd); elif [[ -f "${p}" ]]; then echo "$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; else echo "${p}"; fi
}
get_ext() { local f=$(basename -- "$1"); echo "${f##*.}"; }
random_string() { local l="${1:-16}"; if is_cmd tr && [[ -r /dev/urandom ]]; then LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${l}"; echo; else printf "%s" "$RANDOM$RANDOM$RANDOM" | head -c "${l}"; echo; fi; }
to_lower() { echo "${1,,}"; }
to_upper() { echo "${1^^}"; }
trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; echo -n "${v}"; }

join_by() { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }
slugify() { echo "${1}" | tr '[:upper:]' '[:lower:]' | tr -sc '[:alnum:]' '-' | tr -s '-' | sed 's/^-//;s/-$//'; }
indent() { local i="${1:-4}"; local s; printf -v s "%${i}s" ""; sed "s/^/${s}/"; }
hr() { local c="${1:--}" w="${2:-80}" l; printf -v l "%${w}s" ""; echo "${l// /$c}"; }
run() { if [[ "${DRY_RUN}" -eq 1 ]]; then log INFO "[DRY-RUN] $*"; else "$@"; fi; }
spinner() {
    local pid=$1 delay=0.1 spin='|/-\'
    if [[ ! -t 1 ]]; then wait "$pid"; return $?; fi
    tput civis
    while kill -0 "$pid" 2>/dev/null; do local t=${spin#?}; printf " [%c]  " "$spin"; spin=$t${spin%"$t"}; sleep $delay; printf "\b\b\b\b\b\b"; done
    printf "    \b\b\b\b"; tput cnorm; wait "$pid"; return $?
}
backup() { local f="$1"; [[ -f "$f" ]] || return 1; local b="${f}.$(timestamp).bak"; cp -p "$f" "$b"; echo "$b"; }
mktemp_file() { local f=$(mktemp); __temp_files+=("${f}"); echo "${f}"; }
mktemp_dir() { local d=$(mktemp -d); __temp_files+=("${d}"); echo "${d}"; }
get_json_val() { if is_cmd jq; then echo "${1}" | jq -r "${2}"; else log WARN "jq not installed"; return 1; fi; }
lock() {
    local l="${1:-/tmp/${__base}.lock}"; if [[ -e "${l}" ]]; then local p=$(cat "${l}"); kill -0 "${p}" 2>/dev/null && die "Already running (PID: ${p})"; fi
    echo "$$" > "${l}"; readonly __lockfile="${l}"
}
unlock() { [[ -n "${__lockfile:-}" ]] && rm -f "${__lockfile}"; }
pause() { read -p "${1:-Press [Enter] to continue...}"; }
load_env() {
    local f="${1:-.env}"; [[ -f "${f}" ]] || return 1
    while IFS='=' read -r k v || [[ -n "${k}" ]]; do [[ "${k}" =~ ^#.*$ || -z "${k}" ]] && continue; k=$(echo "${k}" | tr -d '[:space:]'); v=$(echo "${v}" | tr -d '[:space:]' | sed "s/^'//;s/'$//;s/^\"//;s/\"$//"); export "${k}=${v}"; done < "${f}"
}
wait_for_url() { local u="${1}" t="${2:-30}" c=0; until quiet curl -s --head --request GET "${u}"; do sleep 1; ((c++)); [[ "${c}" -ge "${t}" ]] && return 1; done; return 0; }
quiet() { "$@" >/dev/null 2>&1; }
