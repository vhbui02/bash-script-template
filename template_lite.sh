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

# DESC: An 'echo' wrapper that redirects standard output to standard error
# ARGS: $@ (required): Message(s) to echo
# OUTS: None
# RETS: None
function log() {
    echo "$@" >&2
}

# DESC: Checks if a given binary/command is available in the system's PATH.
# ARGS: $1 (required): Name of the binary/command to check.
# OUTS: Prints an error message to stderr if the binary is missing.
# RETS: Returns 1 if the binary is missing, 0 otherwise.
function check_binary() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log "Missing dependency '$1'"
        return 1
    fi
}

# DESC: Acquire script lock, extracted from script.sh
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: None
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ "${1}" = "system" ]]; then
        lock_dir="/tmp/$(basename "${BASH_SOURCE[0]}").lock"
    elif [[ "${1}" = "user" ]]; then
        lock_dir="/tmp/$(basename "${BASH_SOURCE[0]}").${UID}.lock"
    else
        log "Missing or invalid argument to ${FUNCNAME[0]}()!"
        exit 1
    fi

    if mkdir "${lock_dir}" 2>/dev/null; then
        readonly script_lock="${lock_dir}"
        log "Acquired script lock: ${script_lock}"
    else
        log "Unable to acquire script lock: ${lock_dir}"
        exit 2
    fi
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
# RETS: None
function script_trap_exit() {
    # Remove script execution lock
    if [[ -d "${script_lock-}" ]]; then
        rmdir "${script_lock}"
        log "Cleaned up script lock: ${script_lock}"
    fi
}

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
#IFS=$' '

function main() {
    trap script_trap_exit EXIT
    lock_init "user"

    # start here...
}

# Invoke main with args if not sourced
if ! (return 0 2>/dev/null); then
    main "$@"
fi
