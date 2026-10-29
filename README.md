# git-remote-gs

A minimalist Git remote helper for Google Cloud Storage (`gs://`).

## Overview

`git-remote-gs` allows using Google Cloud Storage buckets as Git remotes without running a dedicated Git server. Each remote repository is represented as a single Git bundle file stored in a GCS bucket.

* **Serverless storage**: Leverages standard GCS object storage for hosting Git repositories.
* **Git bundle architecture**: Entire repository history and references are serialized into Git bundle files for push and fetch operations.
* **Empty repository bootstrapping**: Cloning a nonexistent bundle URL initializes an empty local repo ready for initial commits and pushes.

## Requirements

* `bash`
* `git`
* `gsutil` (authenticated to access target GCS buckets)
* `jq`

## Usage

Once installed in your `$PATH` as `git-remote-gs`, Git automatically invokes it for any `gs://` remote URLs:

```sh
git clone gs://my-bucket/my-repo.bundle
```

Starting a new repository requires no remote setup or bucket pre-configuration. Cloning a nonexistent bundle yields an empty repository whose first push creates the remote bundle transparently, making bootstrapping frictionless and identical to working with an existing repo:

```sh
git clone gs://my-bucket/new-repo.bundle
cd new-repo
git commit --allow-empty -m "initial commit"
git push
```