#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")"/.. && pwd)"
    cd "$REPO_ROOT" || exit 1
}

@test "build.sh generates standalone.sh" {
    [ -f "standalone.sh" ] && rm "standalone.sh"
    run ./build.sh
    [ "$status" -eq 0 ]
    [ -f "standalone.sh" ]
}

@test "standalone.sh contains core and main functions" {
    ./build.sh
    grep -q "function is_sourced()" standalone.sh
    grep -q "main()" standalone.sh
}

@test "standalone.sh is executable" {
    ./build.sh
    [ -x "standalone.sh" ]
}
