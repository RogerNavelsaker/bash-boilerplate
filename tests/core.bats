#!/usr/bin/env bats

load 'test_helper'

setup() {
    source "./core.sh"
}

@test "is_sourced returns true" {
    run is_sourced
    [ "$status" -eq 0 ]
}

@test "slugify transforms string" {
    result="$(slugify 'Hello World! 123')"
    [ "$result" == "hello-world-123" ]
}

@test "is_int validates integers" {
    run is_int "123"
    [ "$status" -eq 0 ]
    run is_int "abc"
    [ "$status" -eq 1 ]
}
