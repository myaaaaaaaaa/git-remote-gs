# Agent Guidelines

* **Containerized experiments**: Run exploratory experiments as self-contained experiments inside Podman containers (`podman run --rm ...`) whenever possible. Due to the filesystem-heavy nature of Git remote helpers, container isolation prevents lingering filesystem garbage and zombie processes on the host system.
* **Formal testing**: Run the standard test suite via `nix flake check`.
