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

declare -gA OPTION_SHORT=()        # --option => -o
declare -gA OPTION_TYPE=()         # --option => type_name
declare -gA OPTION_DEFAULT=()      # --option => default_value
declare -gA OPTION_REQUIRED=()     # --option => true|false
declare -gA OPTION_CONSTRAINTS=()  # --option => constraints
declare -gA OPTION_HELP=()         # --option => help_text

# --optionA, --optionB, --optionC ...
declare -ga ORDERS=()

# --option ==> value
declare -gA VALUES=()

# DESC: Get option name in long form, given its short form
# ARGS: $1 (required): short option name
# OUTS: Option name in stdout
# RETS: 0 on success, 2 on failure
function get_name() {
    if [[ -z "${1-}" ]]; then
        script_exit "Short option name is empty"
    fi
    local -r param="$1"

    for long in "${!OPTION_SHORT[@]}"; do
        local short="${OPTION_SHORT["${long}"]}"
        if [[ "${param}" == "${short}" ]]; then
            echo "${long}"
            return 0
        fi
    done

    script_exit "Unknown short option: ${param}"
}

# ============================================================================ #
# TYPE VALIDATION                                                              #
# ============================================================================ #

# Type validation functions mapping
declare -grA VALIDATORS=(
    ["string"]="validate_string"
    ["int"]="validate_integer"
    ["float"]="validate_float"
    ["path"]="validate_path"
    ["file"]="validate_file"
    ["dir"]="validate_directory"
    ["choice"]="validate_choice"
    ["email"]="validate_email"
    ["url"]="validate_url"
    ["bool"]="validate_boolean"
)

# ============================================================================ #

# DESC: Register a command-line option
# ARGS: --long (required): long-form option name (with -- prefix, e.g. --log-level)
#       --short (optional): short-form option name (with - prefix, e.g. -l)
#       --default (optional): default value
#       --type (optional): type (string|int|float|path|file|dir|choice|email|url|bool).
#       --required (optional): required (true|false).
#       --constraints (optional): constraints (comma-separated for choice type).
#       --help (optional): help text.
# OUTS: OPTION_*, ORDERS and VALUES get populated
# RETS: 0
function register_option() {
    # default configs
    local long=""
    local short=""
    local type="string"
    local default=""
    local required="false"
    local constraints=""
    local help="Option help message"

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --long)
                long="$2"
                shift 2
                ;;
            --short)
                short="$2"
                shift 2
                ;;
            --type)
                type="$2"
                shift 2
                ;;
            --default)
                default="$2"
                shift 2
                ;;
            --required)
                required="$2"
                shift 2
                ;;
            --constraints)
                constraints="$2"
                shift 2
                ;;
            --help)
                help="$2"
                shift 2
                ;;
            *)
                script_exit "Unknown argument for register_option(): $1"
                ;;
        esac
    done

    # Validate --long
    if [[ -z "${long}" ]]; then
        script_exit "register_option: Missing required parameter --long"
    fi

    # syntax
    if [[ ! "${long}" =~ ^-- ]]; then
        script_exit "register_option: --long must start with '--' (got: '${long}')"
    fi

    # duplication
    if [[ -n "${OPTION_TYPE["${long}"]:-}" ]]; then
        script_exit "register_option: Option '${long}' already registered"
    fi

    # Validate short
    if [[ -n "${short}" ]]; then
        # syntax
        if [[ ! "${short}" =~ ^-[[:alnum:]]$ ]]; then
            script_exit "register_option: --short must be format '-x' where x is alphanumeric (got: '${short}')"
        fi

        # duplication
        for existing_key in "${!OPTION_SHORT[@]}"; do
            if [[ "${OPTION_SHORT["${existing_key}"]}" == "${short}" && "${existing_key}" != "${long}" ]]; then
                script_exit "register_option: Short option '${short}' is already used by '${existing_key}'"
            fi
        done
    fi

    # Validate type
    if [[ -z "${VALIDATORS["${type}"]:-}" ]]; then
        script_exit "register_option: Unknown type '${type}'. Valid types: ${!VALIDATORS[*]}"
    fi

    # Populate storage arrays
    OPTION_SHORT["${long}"]="${short}"
    OPTION_DEFAULT["${long}"]="${default}"
    OPTION_HELP["${long}"]="${help}"
    OPTION_TYPE["${long}"]="${type}"
    OPTION_REQUIRED["${long}"]="${required}"
    OPTION_CONSTRAINTS["${long}"]="${constraints}"

    ORDERS+=("${long}")
    VALUES["${long}"]="${default}"

    # first validation
    validate_option "${long}"
}

# DESC: Register built-in options
# ARGS: None
# OUTS: Built-in options are registered
# RETS: 0 on success
function register_builtin_options() {
    register_option \
        --long "--help" \
        --short "-h" \
        --type "bool" \
        --default "false" \
        --required "false" \
        --help "Display this help and exit"

    register_option \
        --long "--log-level" \
        --short "-l" \
        --type "choice" \
        --default "INF" \
        --constraints "DBG,INF,WRN,ERR" \
        --required "false" \
        --help "Specify the log level to display"

    register_option \
        --long "--timestamp" \
        --short "-t" \
        --type "bool" \
        --default "false" \
        --required "false" \
        --help "Enable timestamp output"

    register_option \
        --long "--no-color" \
        --short "-n" \
        --type "bool" \
        --default "false" \
        --required "false" \
        --help "Disable color output"

    register_option \
        --long "--quiet" \
        --short "-q" \
        --type "bool" \
        --default "false" \
        --required "false" \
        --help "Run silently unless an error is encountered"
}

# ============================================================================ #
# TYPE VALIDATION                                                              #
# ============================================================================ #

# DESC: Validate string parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 always (string validation always passes unless empty and required)
function validate_string() {
    if [[ -z "${1-}" ]]; then
        script_exit "String is empty"
    fi

    local -r value="$1"
}

# DESC: Validate integer parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: min,max)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if the argument is not integer or the value doesn't satisfy the containsts
function validate_integer() {
    if [[ -z "${1-}" ]]; then
        script_exit "Integer is empty"
    fi

    local -r value="$1"
    local -r constraints="${2:-}"

    if ! [[ "${value}" =~ ^-?[0-9]+$ ]]; then
        script_exit "Not a valid integer: ${value}"
    fi

    if [[ -n "${constraints}" ]]; then
        # both can be empty, but must have a comma
        if [[ ! "${constraints}" =~ ^-?[0-9]*,?-?[0-9]*$ ]]; then
            script_exit "Invalid constraints format for integer: '${constraints}'. Expected format: min,max"
        fi
        IFS=',' read -r min max <<<"${constraints}"
        if [[ -n "${min}" && "${value}" -lt "${min}" ]]; then
            error "Value ${value} is below minimum ${min}"
            return 1
        fi
        if [[ -n "${max}" && "${value}" -gt "$max" ]]; then
            error "Value ${value} is above maximum ${max}"
            return 1
        fi
    fi
}

# DESC: Validate float parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: min,max)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if the argument is not float or the value doesn't satisfy the constraints
function validate_float() {
    if [[ -z "${1-}" ]]; then
        script_exit "Float is empty"
    fi

    local -r value="$1"
    local -r constraints="${2:-}"

    if ! [[ "${value}" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        script_exit "Not a valid float: ${value}"
    fi

    if [[ -n "${constraints}" ]]; then
        # both can be empty, but must have a comma
        if [[ ! "${constraints}" =~ ^-?[0-9]*\.?[0-9]*,?-?[0-9]*\.?[0-9]*$ ]]; then
            script_exit "Invalid constraints format for float: '${constraints}'. Expected format: min,max"
        fi
        IFS=',' read -r min max <<<"${constraints}"

        if [[ -n "${min}" ]]; then
            check_binary "bc" "fatal"
            # shellcheck disable=SC2312
            local -r is_below_min="$(echo "$value < $min" | bc -l)"
            if [[ -n "${is_below_min}" && "${is_below_min}" -eq 1 ]]; then
                script_exit "Value ${value} is below minimum ${min}"
            fi
        fi

        if [[ -n "${max}" ]]; then
            check_binary "bc" "fatal"
            # shellcheck disable=SC2312
            local -r is_above_max="$(echo "$value > $max" | bc -l)"
            if [[ -n "${is_above_max}" && "${is_above_max}" -eq 1 ]]; then
                script_exit "Value ${value} is above maximum ${max}"
            fi
        fi
    fi
}

# DESC: Validate path parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if path is empty
function validate_path() {
    if [[ -z "${1-}" ]]; then
        script_exit "Path is empty"
    fi

    # basic path validation:
    # - absolute path
    # - only alphanumeric, slash, hyphen, underscore are allowed
    # - path must not end with a slash character, except `/` (the root)`
    # ref: https://www.baeldung.com/java-regex-check-linux-path-valid
    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    if [[ ! "${value}" =~ ^/|(/[_[:alnum:]]+)+$ ]]; then
        script_exit "Not a valid path: ${value}"
    fi
}

# DESC: Validate file parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: must_exist)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if file path is empty or doesn't exist when must_exist is set
function validate_file() {
    if [[ -z "${1-}" ]]; then
        script_exit "File path is empty"
    fi

    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    local -r constraints="${2:-}"

    # update more constraints in the future...
    if [[ -n "${constraints}" && ! "${constraints}" =~ ^(must_exist)$ ]]; then
        script_exit "Invalid constraints format for file: '${constraints}'. Expected format: must_exist"
    fi

    if [[ "${constraints}" == "must_exist" && ! -f "${value}" ]]; then
        script_exit "File does not exist: ${value}"
    fi
}

# DESC: Validate directory parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: must_exist)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if directory path is empty or doesn't exist when must_exist is set
function validate_directory() {
    if [[ -z "${value}" ]]; then
        script_exit "Directory path is empty"
    fi

    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    local -r constraints="${2:-}"

    # update more constraints in the future...
    if [[ -n "${constraints}" && ! "${constraints}" =~ ^(must_exist)$ ]]; then
        script_exit "Invalid constraints format for directory: '${constraints}'. Expected format: must_exist"
    fi

    if [[ "${constraints}" == "must_exist" && ! -d "${value}" ]]; then
        script_exit "Directory does not exist: ${value}"
    fi

    return 0
}

# DESC: Validate choice parameter
# ARGS: $1 (required): value to validate
#       $2 (required): constraints (comma-separated)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if choice is invalid or no constraints provided
function validate_choice() {
    if [[ -z "${1-}" ]]; then
        script_exit "Choice value is empty"
    fi
    if [[ -z "${2-}" ]]; then
        script_exit "Constraints is empty"
    fi

    local -r value="$1"
    local -r constraints="$2"

    IFS=',' read -ra choice_array <<<"${constraints}"
    for choice in "${choice_array[@]}"; do
        if [[ "${value}" == "${choice}" ]]; then
            return 0
        fi
    done

    script_exit "Invalid choice: ${value}. Use: ${constraints//,/, }"
}

# DESC: Validate email parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if email format is invalid
function validate_email() {
    if [[ -z "${1-}" ]]; then
        script_exit "Email is empty"
    fi

    local -r value="$1"
    local -r email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if ! [[ "${value}" =~ ${email_regex} ]]; then
        script_exit "Not a valid email address: ${value}"
    fi
}

# DESC: Validate URL parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if URL format is invalid
function validate_url() {
    if [[ -z "${1-}" ]]; then
        script_exit "URL is empty"
    fi

    local -r value="$1"
    local -r url_regex="^https?://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(/.*)?$"

    if ! [[ "${value}" =~ ${url_regex} ]]; then
        script_exit "Not a valid URL: ${value}"
    fi
}

# DESC: Validate boolean parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if boolean format is invalid
function validate_boolean() {
    if [[ -z "${1-}" ]]; then
        script_exit "Boolean is empty"
    fi

    local -r value="$1"
    case "${value,,}" in
    true | false | 1 | 0 | yes | no | y | n)
        return 0
        ;;
    *)
        script_exit "Not a valid boolean value: ${value}. Use: true/false, 1/0, yes/no, y/n"
        ;;
    esac
}

# ============================================================================ #
# OPTION PARSER                                                                #
# ============================================================================ #

# DESC: Parse command-line parameters using declared options and arguments
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: VALUES populated with parsed parameters
# RETS: 0 on success, 2 on failure
function parse_params() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local param="$1"
        shift

        case "${param}" in
        --help | -h)
            print_help_message
            exit 0
            ;;
        --*=* | -*=* | --* | -*)
            # Handle all option formats: --long=value, -s=value, --long value, -s value

            local name value
            local no_equal=false
            if [[ "${param}" == --*=* ]]; then
                name="${param%%=*}"
                value="${param#*=}"
            elif [[ "${param}" == -*=* ]]; then
                name="$(get_name "${param%%=*}")"
                value="${param#*=}"
            elif [[ "${param}" == --* ]]; then
                name="${param}"
                no_equal=true
            elif [[ "${param}" == -* ]]; then
                name="$(get_name "${param}")"
                no_equal=true
            fi

            # extract the type to determine how to handle the value
            local type="${OPTION_TYPE["${name}"]:-}"
            if [[ -z "${type}" ]]; then
                script_exit "Option not found: ${name}"
            fi

            # Boolean options are flags, presence means true
            if [[ "${type}" == "bool" ]]; then
                # If user explicitly provides a value with =, validate it
                if [[ "${no_equal}" == false ]]; then
                    # Allow --flag=true or --flag=false for explicit control
                    if [[ "${value}" != "true" && "${value}" != "false" ]]; then
                        script_exit "Boolean option ${name} requires 'true' or 'false', got: '${value}'"
                    fi
                else
                    # Flag specified without value = true
                    value=true
                fi
            else
                # Non-boolean options require a value
                if [[ "${no_equal}" == true ]]; then
                    if [[ $# -eq 0 ]]; then
                        script_exit "Option requires a value: ${name}"
                    fi
                    value="${1}"
                    shift
                fi
            fi

            VALUES["${name}"]="${value}"

            # second validation
            validate_option "${name}"
            ;;
        *)
            script_exit "Invalid argument: ${param}"
            ;;
        esac
    done

    # seal off
    readonly OPTION_SHORT
    readonly OPTION_TYPE
    readonly OPTION_DEFAULT
    readonly OPTION_REQUIRED
    readonly OPTION_CONSTRAINTS
    readonly OPTION_HELP

    readonly ORDERS
    readonly VALUES
}

# DESC: Check if an option has been registered and populated value correctly
# ARGS: $1 (required): Option name in long form
# OUTS: Error message on failure
# RETS: 0 on success, 2 on failure
function validate_option() {
    if [[ -z "${1-}" ]]; then
        script_exit "Option is empty"
    fi
    local -r param="${1}"

    local found=false
    local name
    for name in "${ORDERS[@]}"; do
        if [[ "${name}" == "${param}" ]]; then
            readonly found=true
            break
        fi
    done

    if [[ "${found}" == false ]]; then
        script_exit "Option '${param}' not found"
    fi

    local short="${OPTION_SHORT["${name}"]:-}"
    local type="${OPTION_TYPE["${name}"]:-}"
    local default="${OPTION_DEFAULT["${name}"]:-}"
    local required="${OPTION_REQUIRED["${name}"]:-}"
    local constraints="${OPTION_CONSTRAINTS["${name}"]:-}"
    local help="${OPTION_HELP["${name}"]:-}"
    local value="${VALUES["${name}"]:-}"

    # validate short
    if [[ -n "${short}" && ! "${short}" =~ ^-[[:alnum:]]$ ]]; then
        script_exit "Option '${name}' has invalid short name '${short}'"
    fi

    # type validation
    validate_string "${type}"
    if [[ -z "${VALIDATORS[${type}]}" ]]; then
        script_exit "Option '${name}' has invalid type '${type}'"
    fi

    # required validation
    validate_boolean "${required}"

    # default validation
    validate_string "${default}"

    # help validation
    validate_string "${help}"

    # Validate the actual value with its type and constraints
    # NOTE: Validation now happens with actual parsed value, not default
    local -r validator="${VALIDATORS[${type}]}"
    "${validator}" "${value}" "${constraints}"
}

# ============================================================================ #
# HELP MESSAGE GENERATION                                                      #
# ============================================================================ #

# DESC: Generate rich help text automatically
# ARGS: None
# OUTS: Help message
# RETS: 0 on success, 2 on failure
function generate_help() {
    local -a displays=()
    local -a helps=()
    local max_width=0

    # Check if ORDERS array is empty
    if [[ ${#ORDERS[@]} -eq 0 ]]; then
        return
    fi

    for name in "${ORDERS[@]}"; do
        local short="${OPTION_SHORT["${name}"]:-}"
        local default="${OPTION_DEFAULT["${name}"]:-}"
        local help="${OPTION_HELP["${name}"]:-}"
        local type="${OPTION_TYPE["${name}"]:-}"
        local required="${OPTION_REQUIRED["${name}"]:-}"
        local constraints="${OPTION_CONSTRAINTS["${name}"]:-}"

        # Skip if type is missing, it means option not properly registered
        if [[ -z "${type}" ]]; then
            continue
        fi

        local display="${name}"
        if [[ -n "${short}" ]]; then
            display="${short}, ${name}"
        fi

        if [[ "${type}" == "choice" && -n "${default}" ]]; then
            display+="=${default}"
        fi

        if [[ "${required}" == true ]]; then
            help+=" [required]"
        fi

        if [[ -n "${constraints}" ]]; then
            help+=" [constraints: ${constraints//,/, }]"
        fi

        displays+=("${display}")
        helps+=("${help}")

        # Include option displays in overall width calculation
        if [[ ${#display} -gt $max_width ]]; then
            max_width=${#display}
        fi
    done

    # Unified width formatting
    local format_width=$((max_width + 10))

    echo "Options:"

    # Show all options
    if [[ ${#displays[@]} -gt 0 ]]; then
        for i in "${!displays[@]}"; do
            printf "    %-${format_width}s %s\n" "${displays[$i]}" "${helps[$i]}"
        done
    fi
}

# ============================================================================ #
# LOGGING                                                                      #
# ============================================================================ #

# NOTE: Important to set first as we use it in _log() and exit handler
# shellcheck disable=SC2155
readonly ta_none="$(tput sgr0 2>/dev/null || true)"

# Log levels associative array with ascending severity
declare -rA LOG_LEVELS=(["DBG"]=0 ["INF"]=1 ["WRN"]=2 ["ERR"]=3)

# DESC: Core logging function - no dependencies, no recursion risk
# ARGS: $1 (required): Log level number (0-3)
#       $2 (required): Color code
#       $3 (required): Log type (3 chars)
#       $4+ (required): Message
# OUTS: Formatted log message to stderr
# RETS: 0
function _log() {
    local -r level_num="$1"
    local color="$2"
    local -r log_type="$3"
    shift 3
    local log_message="$*"
    local timestamp=""

    local -r log_level="${VALUES["--log-level"]}"
    local -r global_level_num="${LOG_LEVELS["${log_level}"]:-}"
    if [[ "${level_num}" -lt "${global_level_num}" ]]; then
        return 0
    fi

    if [[ "${VALUES["--no-color"]}" == true ]]; then
        color="${ta_none}"
    fi

    if [[ "${VALUES["--timestamp"]}" == true ]]; then
        timestamp="$(date +"[%Y-%m-%d %H:%M:%S %z]") "
    fi

    # "${BASH_SOURCE[2]}" -> abs path to script that defined the function that called error() / warn() / info() / debug() functions
    # "${BASH_SOURCE[1]}" -> abs path to script that defined error() / warn() / info() / debug() functions
    # "${BASH_SOURCE[0]}" -> abs path to script that defined _log() function
    local caller=$(basename "${BASH_SOURCE[2]}")
    # "${BASH_LINENO[1]}" -> where sucesss() / error() / warn() / info() / debug() get called
    # "${BASH_LINENO[0]}" -> where log() get called
    local lineno="${BASH_LINENO[1]}"

    # check whether main() call script_exit() and script_exit() called error() / warn() / info() / debug()
    if [[ "${FUNCNAME[2]}" == "script_exit" ]]; then
        caller="$(basename "${BASH_SOURCE[3]}")"
        lineno="${BASH_LINENO[2]}"
    fi

    # Simple path colorization
    if [[ "${log_message}" =~ ^(/|\./|~/) ]]; then
        log_message="${fg_green:-$ta_none}${log_message}${ta_none}"
    fi

    # Replace $HOME with ~ (safe parameter expansion)
    log_message="${log_message//\/home\/${USER-}/\~}"

    # Log to stdout
    printf "%s%s[%d]: %b[%s]%b %s\n" \
        "${timestamp}" "${caller}" "${lineno}" \
        "${color}" "${log_type}" "${ta_none}" \
        "${log_message}"
}

# List of logging functions in different levels
function debug() { _log "${LOG_LEVELS["DBG"]}" "${ta_none}" "DBG" "$@"; }
function info() { _log "${LOG_LEVELS["INF"]}" "${ta_bold:-$ta_none}${fg_blue:-$ta_none}" "INF" "$@"; }
function warn() { _log "${LOG_LEVELS["WRN"]}" "${ta_bold:-$ta_none}${fg_yellow:-$ta_none}" "WRN" "$@"; }
function error() { _log "${LOG_LEVELS["ERR"]}" "${ta_bold:-$ta_none}${fg_red:-$ta_none}" "ERR" "$@" >&2; }
function critical() {
    printf "%b%s%b" \
        "${ta_bold-$ta_none}${bg_red-$ta_none}${fg_white-$ta_none}" \
        "CRITICAL FAILURE - $*" \
        "${ta_none}\n" >&2
}

# ============================================================================ #

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
# RETS: None
function script_trap_err() {

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate exit code
    local -r exit_code="${1:-1}"

    # Output debug data if in Quiet mode - direct check without function calls
    if [[ "${VALUES["--quiet"]}" == true ]]; then
        # Restore original file output descriptors
        if [[ -n "${SCRIPT_OUTPUT:-}" ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information using printf to avoid recursion
        critical "Abnormal termination of script"
        critical "Script Path:       ${SCRIPT_PATH:-unknown}"
        critical "Script Parameters: ${SCRIPT_PARAMS:-none}"
        critical "Script Exit Code:  ${exit_code}"

        # Print the script log if we have it
        if [[ -n "${SCRIPT_OUTPUT:-}" ]]; then
            critical "Script Output:"
            cat "${SCRIPT_OUTPUT}" >&2 || true
        else
            critical "Script Output: none (failed before log init)"
        fi
    fi

    # Exit with failure status
    exit "${exit_code}"
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
# RETS: None
function script_trap_exit() {
    # Disable the exit trap handler to prevent potential recursion
    trap - EXIT

    cd "${ORIGINAL_CWD}"

    # Remove Quiet mode script log - direct check without function calls
    # NOTE: default value exception
    if [[ "${VALUES["--quiet"]}" == true && -n "${SCRIPT_OUTPUT-}" ]]; then
        rm "${SCRIPT_OUTPUT}"
        debug "Cleaned up script output: ${SCRIPT_OUTPUT}"
    fi

    # Remove script execution lock
    if [[ -d "${SCRIPT_LOCK-}" ]]; then
        rmdir "${SCRIPT_LOCK}"
        debug "Cleaned up script lock: ${SCRIPT_LOCK}"
    fi

    # Restore terminal colors
    printf '%b' "${ta_none}"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Error message to print on exit
# OUTS: None
# RETS: None
# NOTE: The convention used in this script for exit codes is:
#       1: Abnormal exit due to external error (missing dependency, network is not accessible, target dir existed, )
#       2: Abnormal exit due to script error (empty argument, undefined options, ...)
function script_exit() {
    if [[ -z "${1-}" ]]; then
        critical "${FUNCNAME[0]}: Invalid arguments: $*"
        exit 2
    fi

    critical "${FUNCNAME[1]}: ${1}"
    script_trap_err 3
}

# DESC: Initialise color variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# RETS: None
# NOTE: If --no-color was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function color_init() {

    # NOTE: no need default value here, color_init() runs after parse_params()
    if [[ "${VALUES["--no-color"]}" == false ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2>/dev/null || true)"
        readonly ta_uscore="$(tput smul 2>/dev/null || true)"
        readonly ta_blink="$(tput blink 2>/dev/null || true)"
        readonly ta_reverse="$(tput rev 2>/dev/null || true)"
        readonly ta_conceal="$(tput invis 2>/dev/null || true)"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2>/dev/null || true)"
        readonly fg_blue="$(tput setaf 4 2>/dev/null || true)"
        readonly fg_cyan="$(tput setaf 6 2>/dev/null || true)"
        readonly fg_green="$(tput setaf 2 2>/dev/null || true)"
        readonly fg_magenta="$(tput setaf 5 2>/dev/null || true)"
        readonly fg_red="$(tput setaf 1 2>/dev/null || true)"
        readonly fg_white="$(tput setaf 7 2>/dev/null || true)"
        readonly fg_yellow="$(tput setaf 3 2>/dev/null || true)"

        # Background codes
        readonly bg_black="$(tput setab 0 2>/dev/null || true)"
        readonly bg_blue="$(tput setab 4 2>/dev/null || true)"
        readonly bg_cyan="$(tput setab 6 2>/dev/null || true)"
        readonly bg_green="$(tput setab 2 2>/dev/null || true)"
        readonly bg_magenta="$(tput setab 5 2>/dev/null || true)"
        readonly bg_red="$(tput setab 1 2>/dev/null || true)"
        readonly bg_white="$(tput setab 7 2>/dev/null || true)"
        readonly bg_yellow="$(tput setab 3 2>/dev/null || true)"

        # Reset terminal once at the end
        printf '%b' "${ta_none}"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $ORIGINAL_CWD:  The current working directory when the script was run
#       $SCRIPT_PATH:   The full path to the script
#       $SCRIPT_DIR:    The directory path of the script
#       $SCRIPT_NAME:   The file name of the script
#       $SCRIPT_PARAMS: The original parameters provided to the script
# RETS: None
# NOTE: $SCRIPT_PATH only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $SCRIPT_DIR and $SCRIPT_NAME variables.
# shellcheck disable=SC2034
function script_init() {
    # Useful variables
    readonly ORIGINAL_CWD="${PWD}"
    readonly SCRIPT_PARAMS="$*"
    readonly SCRIPT_PATH="$(realpath "$0")"
    readonly SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
    readonly SCRIPT_NAME="$(basename "${SCRIPT_PATH}")"
}

# DESC: Initialise Quiet mode
# ARGS: None
# OUTS: $SCRIPT_OUTPUT: Path to the file stdout & stderr was redirected to
# RETS: None
function quiet_init() {

    if [[ "${VALUES["--quiet"]}" == true ]]; then
        # Redirect all output to a temporary file
        # NOTE: comparable with BusyBox `mktemp` inside Alpine Image
        readonly SCRIPT_OUTPUT="$(mktemp -p "/tmp" "${SCRIPT_NAME}.XXXXXX")"
        exec 3>&1 4>&2 1>"${SCRIPT_OUTPUT}" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (required): Scope of script execution lock (system or user)
# OUTS: $SCRIPT_LOCK: Path to the directory indicating we have the script lock
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    if [[ -z "${1-}" ]]; then
        script_exit "Scope is empty"
    fi
    local -r scope="${1}"
    local lock_dir
    if [[ "${scope}" = "system" ]]; then
        lock_dir="/tmp/${SCRIPT_NAME}.lock"
    elif [[ "${scope}" = "user" ]]; then
        lock_dir="/tmp/${SCRIPT_NAME}.${UID}.lock"
    else
        script_exit "Invalid scope: ${1}"
    fi

    if mkdir "${lock_dir}" 2>/dev/null; then
        readonly SCRIPT_LOCK="${lock_dir}"
        debug "Acquired script lock: ${SCRIPT_LOCK}" >&2
    else
        script_exit "Unable to acquire script lock: ${lock_dir}"
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# RETS: None
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ -z "${1-}" ]]; then
        script_exit "Path is empty"
    fi

    local temp_path="${1}:"
    if [[ -n "${2:-}" ]]; then
        temp_path="${temp_path}${2}:"
    fi

    local new_path=
    while [[ -n "${temp_path:-}" ]]; do
        local -r path_entry="${temp_path%%:*}"
        case "${new_path}:" in
        *:"${path_entry}":*) ;;
        *)
            new_path="${new_path}:${path_entry}"
            ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    readonly build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
# RETS: 0 (true) if dependency was found, otherwise 1 (false) if failure is not
#       being treated as a fatal error.
function check_binary() {
    if [[ -z "${1-}" ]]; then
        script_exit "Binary is empty"
    fi
    local -r binary="${1}"
    local -r fatal="${2:-}"

    if ! command -v "${binary}" >/dev/null 2>&1; then
        if [[ -n "${fatal}" ]]; then
            script_exit "Missing dependency '${binary}'"
        else
            error "Missing dependency '${binary}'"
            return 1
        fi
    fi

    info "Found dependency '${binary}'"
    return 0
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
# RETS: 0 (true) if superuser credentials were acquired, otherwise 1 (false)
function check_superuser() {
    local superuser=
    if [[ "${EUID}" -eq 0 ]]; then
        superuser=true
    elif [[ -z "${1-}" ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            info "Sudo: Updating cached credentials ..."
            if ! sudo -v; then
                error "Sudo: Could not acquire credentials ..."
            else
                # shellcheck disable=SC2312
                local -r test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ "${test_euid}" -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z "${superuser-}" ]]; then
        error "Unable to acquire superuser credentials."
        return 1
    fi

    info "Successfully acquired superuser credentials."
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to --no-sudo or -n to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
# RETS: 0 on success, 1 on failure
function run_as_root() {
    local skip_sudo=
    if [[ "${1-}" =~ ^(--no-sudo|-n)$ ]]; then
        skip_sudo=true
        shift
    fi

    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif [[ -z "${skip_sudo}" ]]; then
        # shellcheck disable=SC2310
        if ! check_binary sudo; then
            script_exit "'sudo' binary is not available."
        fi
        warn "Run the following command with sudo privilege:"
        warn "$*"
        sudo -H -- "$@"
    else
        error "Cannot run command as root: not root user and sudo disabled"
        return 1
    fi
}

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


# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    main "$@"
fi
