#!/usr/bin/env bash

# Bash Script Template (main.sh)
#
# This template uses core.sh for its foundational logic.
# For local development: ensure core.sh is in the same directory.
# For production: use build.sh to generate a standalone script.

# Detect script directory and source core
readonly __main_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${__main_dir}/core.sh" ]]; then
    source "${__main_dir}/core.sh"
else
    echo "Error: core.sh not found at ${__main_dir}/core.sh" >&2
    exit 1
fi

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
    check_bash_version 4
    parse_params "$@"
    cron_init

    log INFO "Script started: ${__base}"
    log DEBUG "Invocation: ${__invocation}"
    
    # Add your logic here
    # Example:
    # box "Processing Data"
    # hr "="
    
    log INFO "Completed successfully!"
    return 0
}

# 10. Sourcing Protection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
