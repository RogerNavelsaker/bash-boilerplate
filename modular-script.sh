#!/usr/bin/env bash

# Modular Bash Script (modular-script.sh)
#
# This script uses the modular library approach by sourcing lib/core.sh.
# This keeps your main script clean and focused on your specific logic.

# Detect script directory for reliable sourcing
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the core library
if [[ -f "${script_dir}/lib/core.sh" ]]; then
    source "${script_dir}/lib/core.sh"
else
    echo "Error: lib/core.sh not found at ${script_dir}/lib/core.sh" >&2
    exit 1
fi

# 8. Argument Parsing
usage() {
    cat <<EOF
Usage: ${__bin} [OPTIONS] [ARGUMENTS]

A modular script using the bash-boilerplate library.

Options:
    -h, --help      Display this help message
    -v, --verbose   Enable debug logging (LOG_LEVEL=7)
    -d, --dry-run   Simulation mode (don't execute commands)
EOF
}

parse_params() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) LOG_LEVEL=7; shift ;;
            -d|--dry-run) DRY_RUN=1; shift ;;
            --)           shift; break ;;
            -?*)          die "Unknown option: $1" ;;
            *)            break ;;
        esac
    done
    args=("$@")
}

# 9. Main Logic
main() {
    check_bash_version 4
    parse_params "$@"

    log INFO "Modular script started..."
    
    # Use library functions
    hr "="
    log INFO "Current OS: ${__os:-Unknown}"
    log INFO "Architecture: $(get_arch; echo ${__arch})"
    
    if is_container; then
        log NOTICE "Running inside a container!"
    fi

    log INFO "Modular script completed successfully."
}

# 10. Sourcing Protection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
