#!/usr/bin/env bash

# ============================================================================ #

## FILE         : clone.sh
## VERSION      : 1.0.0
## DESCRIPTION  : Clone specific template into specific output
## AUTHOR       : silverbullet069
## REPOSITORY   : https://github.com/Silverbullet069/bash-script-template
## LICENSE      : BSD 3-Clause License

## TEMREPO      : https://github.com/Silverbullet069/bash-script-template
## TEMAUTHOR    : Silverbullet069
## TEMLIC       : BSD 3-Clause License

# ============================================================================ #

# shellcheck disable=SC2154

# DESC: Parse command-line parameters using the declarative system
# ARGS: None
# OUTS: SCRIPT_PARSED_VALUES populated with parsed parameters
# RETS: 0
function option_init() {
    register_builtin_options

    register_option \
        --long "--mode" \
        --short "-m" \
        --type "choice" \
        --default "lite" \
        --required "true" \
        --constraints "full,lite,legacy,src"\
        --help "Template mode"

    register_option \
        --long "--output" \
        --short "-o" \
        --type "path" \
        --default "${PWD}/temp.sh" \
        --help "Output file path"

    register_option \
        --long "--yes" \
        --short "-y" \
        --type "bool" \
        --default "false" \
        --help "Skip prompting for metadata"
}

function print_help_message() {

    cat <<EOF

Usage: [DEBUG=1] clone [OPTIONS]

Clone a template.

To simply clone a 'lite' template at the current working directory under the
name of 'temp.sh':

    clone

To create a 'full' template with custom output destination:

    clone -m full -o path/to/script.bash

By default, the script will prompt for information to be placed inside the
header. To skip prompting:

    clone -y ...

EOF

    generate_help
}

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
    local -r mode="${VALUES["--mode"]}"
    local file=
    case "${mode}" in
        legacy)
            file="template_legacy.sh"
            ;;
        full)
            file="template.sh"
            ;;
        lite)
            file="template_lite.sh"
            ;;
        src)
            file="script.sh"
            ;;
        *)
            script_exit "Invalid mode: ${mode}."
            ;;
    esac
    readonly file

    # Source path initialization
    # shellcheck disable=SC2154
    local -r src="${SCRIPT_DIR}/${file}"
    if [[ ! -f "${src}" ]]; then
        script_exit "${src} not found."
    fi

    # shellcheck disable=SC2312
    local -r date="$(date +%Y%m%d_%H%M%S_%N)"

    # Destination path initialization
    # shellcheck disable=SC2312
    local -r dest="$(realpath "${VALUES["--output"]}")"
    if [[ -f "${dest}" ]]; then
        # prevent overwrite
        mv -n "${dest}" "${dest}.${date}.bak"
        warn "Backup ${dest}.${date}.bak is created."
    fi

    # legacy: cp -nLT (follow symlinks, prevent overwrite, refuse copy if ${dest} is dir)
    if ! install -D -m 755 "${src}" "${dest}"; then
        # restore backup if existed
        if [[ -f "${dest}.${date}.bak" ]]; then
            # prevent overwrite
            mv -n "${dest}.${date}.bak" "${dest}"
            warn "${dest} is restored from backup ${dest}.${date}.bak"
        fi

        script_exit "Failed to clone ${src} to ${dest}"
    fi

    # add value to placeholders
    local -r name="$(basename "${dest}")"
    local ver="1.0.0"
    local desc="A general Bash template."
    local author="${USER:-"Silverbullet069"}" # in USER is empty
    local repo="https://github.com/Silverbullet069"
    local lic="BSD 3-Clause License"

    local yes="${VALUES["--yes"]}"
    if [[ "${yes}" == "false" ]]; then
        echo "This utility will walk you through creating a bash script."
        echo "It only covers the most common items, and tries to guess sensible defaults."
        echo "Press ^C at any time to quit."
        echo ""
        # NOTE: -e use `readline` and -i instead text using `readline`
        read -r -e -p "Version: " -i "${ver}" ver
        read -r -e -p "Description: " -i "${desc}" desc
        read -r -e -p "Author: " -i "${author}" author
        read -r -e -p "Git repository: " -i "${repo}" repo
        read -r -e -p "License: " -i "${lic}" lic
        echo ""
    fi
    readonly ver desc author repo lic

    # add value to template-related placeholders
    local -r updated="$(stat -c "%y" "${src}" 2>/dev/null)"
    local -r tag="$(ls -t "${SCRIPT_DIR}/.git/refs/tags" | head -n1)"

    # Replace placeholders in the cloned file
    if ! sed -i \
        -e "s|@NAME@|${name}|g" \
        -e "s|@VER@|${ver}|g" \
        -e "s|@DESC@|${desc}|g" \
        -e "s|@AUTHOR@|${author}|g" \
        -e "s|@REPO@|${repo}|g" \
        -e "s|@LIC@|${lic}|g" \
        -e "s|@UPDATED@|${updated}|g" \
        -e "s|@MODE@|${mode}|g" \
        -e "s|@TAG@|${tag}|g" \
        "${dest}"; then
        script_exit "Failed to replace placeholders in ${dest}."
    fi

    if [[ "${mode}" == "src" ]]; then
        local -r path="${SCRIPT_DIR}/source.sh"
        if [[ ! -f "${path}" ]]; then
            script_exit "${path} not found"
        fi
        sed -i -e "s|^source.*source\.sh\"$|source \"${path}\"|g" "${dest}"
        info "Replaced source directory inside ${dest} successfully."
    fi

    info "Cloned ${src} to ${dest} successfully."
}

# ============================================================================ #
# Helper flags
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
