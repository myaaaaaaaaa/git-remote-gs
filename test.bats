#!/usr/bin/env bats

git_count() {
	git rev-list --count HEAD
}

setup() {
	bats_load_library bats-support
	bats_load_library bats-assert

	export GIT_TERMINAL_PROMPT=0

	export GS_MOCK_DIR="${BATS_TEST_TMPDIR}/mock_gs"
	mkdir -p "${GS_MOCK_DIR}/mybucket"

	export REPO_DIR="${BATS_TEST_TMPDIR}/repo"
	mkdir -p "$REPO_DIR"
}

@test "push to and clone from gs" {
	cd "$REPO_DIR"

	# Setup first repo and push
	mkdir repo1
	cd repo1
	git init
	git branch -m main
	git config user.email "test@test.com"
	git config user.name "test"

	echo "hello" > README.md
	git add README.md
	git commit -m "initial"

	git remote add origin gs://mybucket/repo.bundle
	git push origin main

	# Clone into second repo
	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo2

	cd repo2
	assert_equal "$(git_count)" "1"
	assert_equal "$(cat README.md)" "hello"
}

@test "push, clone, push from second, pull from first" {
	cd "$REPO_DIR"

	mkdir repo1
	cd repo1
	git init
	git branch -m main
	git config user.email "test@test.com"
	git config user.name "test"

	echo "hello" > README.md
	git add README.md
	git commit -m "initial"
	git remote add origin gs://mybucket/repo.bundle
	git push origin main

	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo2
	cd repo2
	assert_equal "$(git_count)" "1"
	git config user.email "test2@test.com"
	git config user.name "test2"
	echo "world" > README.md
	git add README.md
	git commit -m "update"
	git push origin main

	cd "$REPO_DIR"/repo1
	git fetch origin
	git rebase origin/main
	assert_equal "$(git_count)" "2"
	assert_equal "$(cat README.md)" "world"
}

@test "clone nonexistent repo, commit, and push" {
	cd "$REPO_DIR"
	# clone a non-existent bundle yields an empty directory, warning of empty repo
	run git clone gs://mybucket/empty.bundle repo_empty
	assert_success

	cd repo_empty
	git config user.email "test@test.com"
	git config user.name "test"
	echo "initialized" > README.md
	git add README.md
	git commit -m "initial"
	git push

	# Verify by cloning the newly created remote bundle into another repo
	cd "$REPO_DIR"
	git clone gs://mybucket/empty.bundle repo_clone
	cd repo_clone
	assert_equal "$(git_count)" "1"
	assert_equal "$(cat README.md)" "initialized"
}

@test "clone fails loudly on truncated bundle (partial download)" {
	cd "$REPO_DIR"

	mkdir repo1
	cd repo1
	git init
	git branch -m main
	git config user.email "test@test.com"
	git config user.name "test"

	echo "hello" > README.md
	git add README.md
	git commit -m "initial"

	git remote add origin gs://mybucket/truncated.bundle
	git push origin main

	local bundle="${GS_MOCK_DIR}/mybucket/truncated.bundle"
	local size
	size=$(stat -c%s "$bundle")
	truncate -s $((size / 2)) "$bundle"

	cd "$REPO_DIR"
	run git clone gs://mybucket/truncated.bundle repo2
	assert_failure
	assert_output --partial "unexpected end of file"
	[ ! -d repo2 ]
}

@test "clone fails loudly on corrupted bundle header" {
	echo "corrupt bundle data" > "${GS_MOCK_DIR}/mybucket/corrupted.bundle"

	cd "$REPO_DIR"
	run git clone gs://mybucket/corrupted.bundle repo2
	assert_failure
	assert_output --partial "not in gzip format"
	[ ! -d repo2 ]
}

@test "conflicting non-fast-forward push is rejected and preserves remote commit" {
	cd "$REPO_DIR"

	mkdir repo1
	cd repo1
	git init
	git branch -m main
	git config user.email "test@test.com"
	git config user.name "test"

	echo "base" > file.txt
	git add file.txt
	git commit -m "base commit C"
	git remote add origin gs://mybucket/repo.bundle
	git push origin main

	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo2
	cd repo2
	git config user.email "test2@test.com"
	git config user.name "test2"

	# repo1 creates and pushes commit D1
	cd "$REPO_DIR"/repo1
	echo "change D1" > file.txt
	git add file.txt
	git commit -m "commit D1"
	git push origin main

	# repo2 creates conflicting commit D2 without fetching D1
	cd "$REPO_DIR"/repo2
	echo "change D2" > file.txt
	git add file.txt
	git commit -m "commit D2"

	# Non-fast-forward push must fail and be rejected
	run git push origin main
	assert_failure
	assert_output --partial "non-fast-forward"

	# Remote repository must still preserve D1
	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo3
	cd repo3
	assert_equal "$(git_count)" "2"
	assert_equal "$(cat file.txt)" "change D1"
	assert_equal "$(git log -1 --pretty=%B)" "commit D1"
}

@test "force push overwrites conflicting remote commit" {
	cd "$REPO_DIR"

	mkdir repo1
	cd repo1
	git init
	git branch -m main
	git config user.email "test@test.com"
	git config user.name "test"

	echo "base" > file.txt
	git add file.txt
	git commit -m "base commit C"
	git remote add origin gs://mybucket/repo.bundle
	git push origin main

	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo2
	cd repo2
	git config user.email "test2@test.com"
	git config user.name "test2"

	# repo1 creates and pushes commit D1
	cd "$REPO_DIR"/repo1
	echo "change D1" > file.txt
	git add file.txt
	git commit -m "commit D1"
	git push origin main

	# repo2 creates conflicting commit D2
	cd "$REPO_DIR"/repo2
	echo "change D2" > file.txt
	git add file.txt
	git commit -m "commit D2"

	# Normal push fails
	run git push origin main
	assert_failure

	# Force push succeeds
	git push --force origin main

	# Remote repository must now have D2, with D1 overwritten
	cd "$REPO_DIR"
	git clone gs://mybucket/repo.bundle repo3
	cd repo3
	assert_equal "$(git_count)" "2"
	assert_equal "$(cat file.txt)" "change D2"
	assert_equal "$(git log -1 --pretty=%B)" "commit D2"
	run git log --grep="commit D1"
	assert_output ""
}

