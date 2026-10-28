#!/usr/bin/env bats

setup() {
	bats_load_library bats-support
	bats_load_library bats-assert
}

@test "prints Hello, world! when no arguments are given" {
	run app.sh
	assert_success
	assert_output "Hello, world!"
}

@test "prints Hello, Nix! when Nix is given as argument" {
	run app.sh "Nix"
	assert_success
	assert_output "Hello, Nix!"
}
