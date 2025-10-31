# Bash Script Template

[![Tests](https://github.com/Silverbullet069/bash-script-template/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Silverbullet069/bash-script-template/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/Silverbullet069/bash-script-template?include_prereleases&label=version)](https://github.com/Silverbullet069/bash-script-template/releases/latest)
[![License: BSD-3-Clause](https://img.shields.io/github/license/Silverbullet069/bash-script-template)](https://opensource.org/license/bsd-3-clause)

A production-ready Bash scripting template with best practices, robust error handling, and useful utilities built-in.

## Table of Contents

-   [License](#license)
-   [Features](#features)
-   [Setup](#setup)
-   [Architecture](#architecture)
-   [Usage](#usage)
-   [Design Decisions](#design-decisions)

## License

Licensed under [BSD 3-Clause License](LICENSE).

## Features

-   **Zero dependencies:** All code is original and thoroughly audited by the author.
-   **Options-only design:** No positional arguments or subcommands—options are the single source of truth, prioritizing simplicity.
-   **Structured option handling:** Options are defined with clear metadata, allowing reliable registration, parsing, and validation.
-   **Multi-level, color-coded logging:** Output messages at five levels (Debug, Info, Warning, Error, Critical) with color support.
-   **Reliable locking mechanism:** Prevents concurrent script execution.
-   **Graceful termination handling:** Comprehensive trap handlers for `EXIT` and `ERR`.
-   **Quiet mode:** Supports silent operation.
-   **Flexible modes:** Choose from four modes (lite, full, legacy, source/script) to suit different use cases.

## Setup

Clone the repository:

```sh
git clone --depth=1 https://github.com/Silverbullet069/bash-script-template.git
cd bash-script-template
```

Downloaded script files aren't executable by default. Change scripts permissions:

```sh
chmod +x *.sh && chmod -x source.sh
```

(optional) Create a symlink out of `clone.sh`:

> [!IMPORTANT]
>
> Make sure `~/.local/bin` is inside your `PATH` environment variable.

```sh
ln -s "$(PWD)/clone.sh" ~/.local/bin/clone
```

Create your first template:

```sh
clone
clone -m full -o path/to/script.bash
# read more: clone -h
```

> [!TIP]
> Use `.bash` extension if preferred - although both `.sh` and `.bash` are supported.

## Architecture

| File                 | Purpose                                               |
| -------------------- | ----------------------------------------------------- |
| `template.sh`        | Self-contained script combining all functionality     |
| `template_lite.sh`   | A small, simple yet reliable template script          |
| `template_legacy.sh` | `template.sh` version 2.4.0                           |
| `source.sh`          | Reusable library functions                            |
| `script.sh`          | Main script template                                  |
| `build.sh`           | Merges `source.sh` + `script.sh` → `template.sh`      |
| `clone.sh`           | Helper to clone template with placeholder replacement |

## Usage

### Option 1: `script.sh` (Most recommended) and `template.sh`

Register new options by writing into `options_init()`:

```sh
function option_init() {
    # NOTE: long-name, short-name, default, help, type, required, constraints
    # register_option ...

    # CAUTION: --help must be placed as the first option in the built-in options list
    # CAUTION: I add a blank link on top of this function inside help message
    register_option "--help" "-h" false "Display this help and exit" "bool"
    register_option "--log-level" "-l" "INF" "Specify log level" "choice" false "DBG,INF,WRN,ERR"
    register_option "--timestamp" "-t" false "Enable timestamp output" "bool"
    register_option "--no-color" "-n" false "Disable color output" "bool"
    register_option "--quiet" "-q" false "Run silently unless an error is encountered" "bool"
}
```

The `register_option()` functions takes 7 parameters: long-name, short-name, default, help, type, required, constraints.

After that, write into `main()` function:

```sh
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
}
```

### Option 2: `template_lite.sh`

Write directly into `main()` function:

```sh
function main() {
    trap script_trap_exit EXIT
    lock_init "user"

    # start here
    # ...
}
```

### Option 3: `template_legacy.sh` (Not recommended)

Add options to the `parse_params()` function using this pattern:

```bash
function parse_params() {
    # ...
    case "${param}" in
        -m | --mock)
            ### Description for mock option. @DEFAULT:default_value@

            # Add validation logic here
            # ...

            # variable naming convention: _option_<option-name>
            _option_mock="${1-}"
            shift
            ;;
        # ...
    esac
}
```

**Parsing rules:**

-   Lines starting with `###` become help text displayed when specified `-h|--help` option
-   Use `@DEFAULT:value@` to set default values. It's automatically removed from help text.
-   For boolean flags, omit the value assignment and shift.

**Example script:**

```bash
#!/usr/bin/env bash
source source.sh

function parse_params() {
    # Add your custom options here
    case "${param}" in
        -f | --file)
            ### Input file path. @DEFAULT:input.txt@
            _option_file="${1}"
            shift
            ;;
        # ...built-in options...
    esac
}

function main() {
    script_init "$@"
    parse_params "$@"

    info "Processing file: ${_option_file}"
    # Your logic here
}

main "$@"
```

## Design Decisions

-   **Options-only approach:** This template is designed to handle options exclusively—no subcommands or positional arguments. For complex multi-command CLIs, use mature frameworks like Click (Python), Cobra (Go), or similar tools that are battle-tested for subcommand handling.
-   **Conservative default syntax** (e.g. `${param:-}`): Use only for **optional arguments** and explicit exceptions. **AVOID overusing on every variable.**
-   **Fail-fast philosophy:**
    -   Enable `set -e` to terminate the script when undefined variables are referenced unexpectedly.
    -   Use `script_exit()` to halt execution on critical logic failures.
    -   Avoid using log ERR messages and return non-zero exit codes to replace `script_exit()`
-   **Function argument validation:** Implement conditional checks `[[ -z ... ]]` with `script_exit()`, then assign positional parameters (e.g., `$1, $2`) to descriptive local variables (e.g. `$param_name`).
-   **Logging strategy:**
    -   Log in both reusable functions and calling functions.
    -   Calling functions may suppress reusable function output via pipe redirection.
    -   Success messages in reusable functions are optional (DBG level).
    -   Success messages in calling functions are mandatory (INF level).
-   **Logging message convention:** `<function name> (optional): N + <V-ed> + O: <variable>`. **AVOID modifying this format** as it may break existing test cases.
-   **Omit redundant `return 0`**: Unnecessary at function end.
-   **Enable `set -e`**: Forces immediate exit on non-zero exit codes. Despite complexity and edge cases with expected failures, this template enables it because:

    -   Scripts written for `errexit` compatibility work without it, but not vice versa
    -   Production benefits outweigh drawbacks
    -   Can be disabled when necessary without breaking functionality

-   **Enable `set -u`**: Exits when expanding unset variables, catching typos and premature variable access. Enabled following the same rationale as `errexit` - better to maintain compatibility while allowing selective disabling.
