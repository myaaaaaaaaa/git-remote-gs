#!/usr/bin/env bats

setup() {
	# Ensure git-remote-gs is in PATH
	export PATH="${BATS_TEST_DIRNAME}:${PATH}"
	
	export BIN_DIR="${BATS_TEST_TMPDIR}/bin"
	mkdir -p "$BIN_DIR"
	cat << 'MOCK' > "${BIN_DIR}/gsutil"
#!/bin/sh
if [[ "$1" == "-q" ]]; then
	shift
fi
cmd=$1
shift

case "$cmd" in
	stat)
		url=$1
		path="${url/gs:\/\//$GS_MOCK_DIR/}"
		if [ -f "$path" ]; then
			exit 0
		else
			exit 1
		fi
		;;
	cp)
		if [[ "$1" == "-q" ]]; then
			shift
		fi
		src=$1
		dst=$2
		src_path="${src/gs:\/\//$GS_MOCK_DIR/}"
		dst_path="${dst/gs:\/\//$GS_MOCK_DIR/}"
		mkdir -p "$(dirname "$dst_path")"
		cp "$src_path" "$dst_path"
		;;
esac
MOCK
	chmod +x "${BIN_DIR}/gsutil"
	export PATH="${BIN_DIR}:${PATH}"
	
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
	GIT_TERMINAL_PROMPT=0 git push origin main
	
	# Clone into second repo
	cd "$REPO_DIR"
	GIT_TERMINAL_PROMPT=0 git clone gs://mybucket/repo.bundle repo2
	
	cd repo2
	[ "$(cat README.md)" = "hello" ]
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
	GIT_TERMINAL_PROMPT=0 git push origin main
	
	cd "$REPO_DIR"
	GIT_TERMINAL_PROMPT=0 git clone gs://mybucket/repo.bundle repo2
	cd repo2
	git config user.email "test2@test.com"
	git config user.name "test2"
	echo "world" > README.md
	git add README.md
	git commit -m "update"
	GIT_TERMINAL_PROMPT=0 git push origin main
	
	cd "$REPO_DIR"/repo1
	GIT_TERMINAL_PROMPT=0 git fetch origin
	GIT_TERMINAL_PROMPT=0 git rebase origin/main
	[ "$(cat README.md)" = "world" ]
}

@test "clone empty repo works gracefully" {
	cd "$REPO_DIR"
	# clone a non-existent bundle yields an empty directory, warning of empty repo
	run env GIT_TERMINAL_PROMPT=0 git clone gs://mybucket/empty.bundle repo_empty
	[ "$status" -eq 0 ]
	[ -d "repo_empty" ]
}
