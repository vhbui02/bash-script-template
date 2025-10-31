#!/usr/bin/env bats

# shellcheck disable=SC2154

setup_file() {
    # Get paths
    export ROOT="$(dirname "${BATS_TEST_DIRNAME}")"
    # export BATS_LIB_PATH="${ROOT}/tests/test_helper"
    export SUT="${ROOT}/template_legacy.sh"

    # Load BATS libraries
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    # Ensure test script exists and is executable
    assert_file_exists "${SUT}"
    assert_file_executable "${SUT}"
}

setup() {
    # NOTE: in order for helper functions to be accessed in each test
    # NOTE: library must be loaded inside setup()
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    local -r script_name=${SUT##*/}
    if [[ -d "/tmp/${script_name}.${UID}.lock" ]]; then
        rmdir "/tmp/${script_name}.${UID}.lock"
    fi
}

teardown() {
    # Clean up after each test case
    :
}

teardown_file() {
    # Clean up after last test case
    :
}

# ============================ CLI Tests ============================

@test "Script runs without arguments" {
    # shellcheck disable=SC2154
    run "${SUT}"

    # Should run without errors
    assert_success
}

@test "Script handles -h, --help option" {
    run "${SUT}" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"

    run "${SUT}" -h
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"
}

@test "Script handles -n, --no-colour option" {
    run "${SUT}"
    assert_success
    local -r output_with_color="${output}"

    # NOTE: Different output expected (no ANSI codes in no-colour mode)
    run "${SUT}" --no-colour
    assert_success
    assert_not_equal "${output_with_color}" "${output}"

    run "${SUT}" -n
    assert_success
    assert_not_equal "${output_with_color}" "${output}"
}

@test "Script handles -l. --log-level option" {
    run "${SUT}"
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    assert_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${SUT}" --log-level ERR
    assert_success
    assert_output --partial "This is an error message"
    refute_output --partial "This is a warning message"
    refute_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${SUT}" --log-level DBG
    assert_success
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    assert_output --partial "This is an info message"
    assert_output --partial "This is a debug message"
}

@test "Script handles -q, --quiet option" {
    run "${SUT}" --quiet
    assert_success
    refute_output

    run "${SUT}" -q
    assert_success
    refute_output
}

@test "Script handles -t, --timestamp option" {
    run "${SUT}" --timestamp
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'

    run "${SUT}" -t
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'
}

@test "Script fails with invalid option" {
    run "${SUT}" --invalid-option
    assert_failure
    assert_output --partial "invalid arguments: --invalid-option"
}

@test "Script creates and releases lock" {
    run "${SUT}"
    assert_success
    assert_dir_not_exists "/tmp/$(basename "${SUT}").${UID}.lock"
}

@test "Script fails when lock already exists" {
    mkdir -p "/tmp/$(basename "${SUT}").${UID}.lock"

    run "${SUT}"
    assert_failure
    assert_output --partial "Unable to acquire script lock"

    # Manual cleanup
    rmdir "/tmp/$(basename "${SUT}").${UID}.lock"
}

@test "info() function logs info message" {
    run bash -c '
        set -e
        source "'"${SUT}"'"
        info "Test info message"
        '
    assert_success
    assert_output --partial "[INF]"
    assert_output --partial "Test info message"
}

@test "warn() function logs warning message" {
    run bash -c '
        set -e
        source "'"${SUT}"'"
        warn "Test warning message"
        '
    assert_success
    assert_output --partial "[WRN]"
    assert_output --partial "Test warning message"
}

@test "error() function logs error message and exits" {
    run bash -c '
        set -e
        source "'"${SUT}"'"
        error "Test error message"
        '
    assert_success
    assert_output --partial "[ERR]"
    assert_output --partial "Test error message"
}

@test "Script DEBUG environment variable enables trace output" {
    # Run the script with DEBUG=1
    DEBUG=1 run "${SUT}"

    # Should run without errors
    assert_success
    assert_output --partial "+"
    assert_output --partial "++"
}
