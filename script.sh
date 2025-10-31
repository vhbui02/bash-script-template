#!/usr/bin/env bash

# ============================================================================ #

## FILE         : @NAME@
## VERSION      : @VER@
## DESCRIPTION  : @DESC@
## AUTHOR       : @AUTHOR@
## REPOSITORY   : @REPO@
## LICENSE      : @LIC@

## TEMREPO      : https://github.com/Silverbullet069/bash-script-template
## TEMMODE      : @MODE@
## TEMVER       : @TAG@
## TEMUPDATED   : @UPDATED@
## TEMLIC       : BSD 3-Clause License

# ============================================================================ #

# ============================================================================ #
# CUSTOM LOGIC                                                                 #
# ============================================================================ #

# DESC: Register the a set of options
# ARGS: None
# OUTS: OPTIONS, ORDERS and VALUES data are populated
# RETS: 0
function option_init() {
    # --help, --log-level, --timestamp, --no-color, --quiet
    register_builtin_options

    # Custom options
    # ...
}

# DESC: Print help message when user declare --help, -h option
# ARGS: None
# OUTS: Help message
# RETS: 0
function print_help_message() {

    cat <<EOF

Usage: [DEBUG=1] @NAME@ [OPTIONS]

Add short description and examples here...

Example:

    Add some examples here...

EOF

    generate_help

}

# ============================================================================ #
# MAIN CONTROL FLOW                                                            #
# ============================================================================ #

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
# RETS: None
function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    option_init
    parse_params "$@"
    quiet_init
    color_init
    lock_init user

    # start here
    # ...

    # Logging helper functions
    error "This is an error message"
    warn "This is a warning message"
    info "This is an info message"
    debug "This is a debug message"

    # Logging internal states
    debug "SCRIPT_NAME: ${SCRIPT_NAME}"
    debug "SCRIPT_PATH: ${SCRIPT_PATH}"
    debug "SCRIPT_DIR: ${SCRIPT_DIR}"
    debug "SCRIPT_PARAMS: ${SCRIPT_PARAMS}"

    debug "Registered options: ${ORDERS[*]}"
    debug "Parsed values:"
    for key in "${!VALUES[@]}"; do
        debug "  ${key} = '${VALUES[$key]}'"
    done
    debug "OPTION_SHORT:" "${OPTION_SHORT[@]}"
    debug "OPTION_DEFAULT:" "${OPTION_DEFAULT[@]}"
    debug "OPTION_TYPE:" "${OPTION_TYPE[@]}"
    debug "OPTION_REQUIRED:" "${OPTION_REQUIRED[@]}"
    debug "OPTION_CONSTRAINTS:" "${OPTION_CONSTRAINTS[@]}"
    debug "OPTION_HELP:" "${OPTION_HELP[@]}"
}

# ============================================================================ #
# SCRIPT INITIALIZATION FLAGS                                                  #
# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    # A better class of script...
    set -o errexit  # Exit on most errors (see the manual)
    set -o nounset  # Disallow expansion of unset variables
    set -o pipefail # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

# Make `for f in *.txt` work when `*.txt` matches zero files
shopt -s nullglob globstar

# Set IFS to preferred implementation
# IFS=$' '

# shellcheck source=source.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    main "$@"
fi
