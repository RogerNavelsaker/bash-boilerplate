#!/usr/bin/env bash
# Main template example
source "$(dirname "$0")/core.sh"
source "$(dirname "$0")/lib/log.sh"

main() {
    info "Starting main process..."
    # Logic goes here
    notice "Finished successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
