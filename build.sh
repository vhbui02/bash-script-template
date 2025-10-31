#!/usr/bin/env bash

# ============================================================================ #

## FILE         : build.sh
## VERSION      : 1.0.0
## DESCRIPTION  : Merge source and script into template
## AUTHOR       : silverbullet069
## REPOSITORY   : https://github.com/Silverbullet069/bash-script-template
## LICENSE      : BSD-3-Clause

# ============================================================================ #

# DESC: An 'echo' wrapper that redirects standard output to standard error
# ARGS: $@ (required): Message(s) to echo
# OUTS: None
# RETS: None
function log() {
    echo "$@" >&2
}

# FUNCTION: check_binary
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
# ARGS: $1 (required): Scope of script execution lock (system or user)
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
        log "Clean up script lock: ${script_lock}"
    fi
}

# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# A better class of script...
set -o errexit  # Exit on most errors (see the manual)
set -o errtrace # Make sure any error trap is inherited
set -o nounset  # Disallow expansion of unset variables
set -o pipefail # Use last non-zero exit code in a pipeline

function build() {
    local -r source_path="${1}"
    local -r script_path="${2}"
    local -r template_path="${3}"

    if [[ ! -f "${source_path}" ]]; then
        log "source.sh not found: ${script_path}"
        exit 1
    fi

    if [[ ! -r "${source_path}" ]]; then
        log "source.sh is unreadable: ${script_path}"
        exit 1
    fi

    if [[ ! -f "${script_path}" ]]; then
        log "script.sh not found: ${script_path}"
        exit 1
    fi

    if [[ ! -r "${script_path}" ]]; then
        log "script.sh is unreadable: ${script_path}"
        exit 1
    fi

    # NOTE: Update the arbitrary values if header changes
    local -r script_header=$(head -n 18 "${script_path}")
    local -r source_body=$(tail -n +12 "${source_path}")
    local -r script_body=$(tail -n +19 "${script_path}" | grep -vE -e '^# shellcheck source=source.sh$' -e '^# shellcheck disable=SC1091$' -e '^source.*source\.sh"$')

    # temporily make it writeable
    chmod 755 "${template_path}"
    {
        log "${script_header}"
        log "${source_body}"
        log "${script_body}"
    } 2>"${template_path}"

    # then, make it read-only
    chmod 555 "${template_path}"

    log "Build ${template_path} successfully."
}

function cleanup() {
    log "Stopping file monitor..."
    exit 0
}

# Main control flow
function main() {
    trap script_trap_exit EXIT
    lock_init "user"

    local -r source_path="$(dirname "${BASH_SOURCE[0]}")/source.sh"
    local -r script_path="$(dirname "${BASH_SOURCE[0]}")/script.sh"
    local -r template_path="$(dirname "${BASH_SOURCE[0]}")/template.sh"

    # initial build
    build "${source_path}" "${script_path}" "${template_path}"

    # simple dev server
    if [[ "${1-}" =~ ^(--monitor|-m)$ ]]; then
        # gracefully stopping dev server
        trap cleanup SIGINT SIGTERM SIGHUP

        inotifywait \
            --monitor \
            --event "close_write" \
            "${source_path}" "${script_path}" \
            | while read -r dir event file; do
                log "Change detected: ${event} on ${dir}${file}"
                # NOTE: add a small delay to allow accumulation of multiple changes
                sleep 1
                build "${source_path}" "${script_path}" "${template_path}"
            done
    fi
}

# Invoke main with args if not sourced
if ! (return 0 2>/dev/null); then
    main "$@"
fi
