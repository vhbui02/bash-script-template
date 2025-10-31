#!/usr/bin/env bats

# shellcheck disable=SC2154

setup_file() {
    # provision testing environment here
    # ...
    export ROOT="$(dirname "${BATS_TEST_DIRNAME}")"
    # export BATS_LIB_PATH="${ROOT}/tests/test_helper"
    export SUT="${ROOT}/clone.sh"

    bats_load_library "bats-support"
    bats_load_library "bats-assert"
    bats_load_library "bats-file"

    export PATH="${ROOT}:${PATH}"

    # Export SUTS associative array for use in subshells
    declare -gA SUTS=(
        ["src"]="script.sh"
        ["full"]="template.sh"
        ["lite"]="template_lite.sh"
        ["legacy"]="template_legacy.sh"
    )

    for sut_key in "${!SUTS[@]}"; do
        local sut_path="${ROOT}/${SUTS["${sut_key}"]}"
        assert_file_exists "${sut_path}"
        assert_file_executable "${sut_path}"
    done
}

setup() {
    # NOTE: in order for helper functions to be accessed in each test
    # NOTE: library must be loaded inside setup()
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    cd "${BATS_TEST_TMPDIR}" || exit 1
}

teardown() {
    # restore proper permissions for clean up operations
    chmod -R 755 "${BATS_TEST_TMPDIR}"
}

teardown_file() {
    # Clean up after last test case
    :
}

# =============================== CUSTOM TESTS =============================== #

@test "Script handles without --output option" {
    local -r path="${BATS_TEST_TMPDIR}/temp.sh"

    run "${SUT}" --yes
    assert_success
    assert_file_exists "${path}"

    assert_file_not_contains "${path}" "@NAME@"
    assert_file_not_contains "${path}" "@VER@"
    assert_file_not_contains "${path}" "@DESC@"
    assert_file_not_contains "${path}" "@AUTHOR@"
    assert_file_not_contains "${path}" "@REPO@"
    assert_file_not_contains "${path}" "@LIC@"

    assert_file_not_contains "${path}" "@MODE@"
    assert_file_not_contains "${path}" "@TAG@"
    assert_file_not_contains "${path}" "@UPDATED@"
}

@test "Script handles with --output option" {
    local -r path="${BATS_TEST_TMPDIR}/test_output.sh"

    run "${SUT}" --yes --output "${path}"
    assert_success
    assert_file_exists "${path}"
}

@test "Script fails when output is pointing to a non-existant directory" {
    run "${SUT}" --yes --output "/path/not/exist"
    assert_failure
    assert_output --partial "validate_path"
    assert_output --partial "Not a valid path"
}

@test "Script handles different modes correctly" {
    for mode in "${!SUTS[@]}"; do
        local path="${BATS_TEST_TMPDIR}/test_${mode}.sh"

        run "${SUT}" --yes --mode "${mode}" --output "${path}"
        assert_success
        assert_file_exists "${path}"

        # shellcheck disable=SC2312
        local author="$(grep -i --color=never "url = git@github.com" "/code/.git/config" | sed -E 's/.*github\.com:([^\/]+)\/.*/\1/')"
        # shellcheck disable=SC2012
        local tag="$(ls -t "${ROOT}/.git/refs/tags" | head -n1)"
        local updated="$(stat -c "%y" "${ROOT}/${SUTS["${mode}"]}")"

        assert_file_not_contains "${path}" "@NAME@"
        assert_file_contains "${path}" "FILE.*$(basename "${path}")" "${path}"

        assert_file_not_contains "${path}" "@VER@"
        assert_file_contains "${path}" "VERSION.*1\.0\.0"

        assert_file_not_contains "${path}" "@DESC@"
        assert_file_contains "${path}" "DESCRIPTION.*A general Bash template"

        assert_file_not_contains "${path}" "@AUTHOR@"
        assert_file_contains "${path}" "AUTHOR.*${author}"

        assert_file_not_contains "${path}" "@REPO@"
        assert_file_contains "${path}" "REPOSITORY.*github.com"

        assert_file_not_contains "${path}" "@LIC@"
        assert_file_contains "${path}" "LICENSE.*BSD 3-Clause License"

        assert_file_not_contains "${path}" "@MODE@"
        assert_file_contains "${path}" "TEMMODE.*${mode}"

        assert_file_not_contains "${path}" "@TAG@"
        assert grep -F "${tag}" "${path}"

        assert_file_not_contains "${path}" "@UPDATED@"
        assert grep -F "${updated}" "${path}"

        if [[ "${mode}" == "src" ]]; then
            assert grep -F "source \"${ROOT}/source.sh\"" "${path}"
        fi
    done
}

@test "Script validates mode parameter correctly" {
    run "${SUT}" --mode invalid --output "${BATS_TEST_TMPDIR}/test.sh"
    assert_failure
    assert_output --partial "validate_choice"
    assert_output --partial "Invalid choice: invalid"
    assert_output --partial "Use: full, lite, legacy, src"
}

@test "Script creates backup when output file exists" {
    # Create an existing file
    echo "existing content" >"${BATS_TEST_TMPDIR}/existing.sh"

    run "${SUT}" --yes --output "${BATS_TEST_TMPDIR}/existing.sh"
    assert_success

    # Check that backup was created
    assert_file_exists "${BATS_TEST_TMPDIR}/existing.sh"
    # shellcheck disable=SC2312
    local -r backup_file=$(find "${BATS_TEST_TMPDIR}" -name "existing.sh.*.bak" | head -1)
    assert_file_exists "${backup_file}"
}
