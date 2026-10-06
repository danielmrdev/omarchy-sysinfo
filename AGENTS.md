# Project Context

`omarchy-sysinfo` is a third-party Omarchy 4 bar widget showing CPU, per-core CPU, RAM, disk, temperature, and fan metrics.

## Tooling

- Runtime: Omarchy 4 / Quickshell QML.
- Data source: Bash, `/proc`, `/sys`, `df`, and `awk`.
- Validate manifest: `omarchy plugin validate .`
- Validate QML: `find . -type f -name '*.qml' -print0 | xargs -0 qmllint -I "$OMARCHY_PATH/shell"`
- Validate script: `bash -n sysinfo.sh`

## Guidance

- Published plugin ID is `danielmrdev.sysinfo`; keep the manifest, QML `moduleName`, logs, and install docs aligned.
- Treat installed copies separately; migrate their shell config and bar layout before changing an existing installation's ID.
- Keep entry-point paths relative and symlink-free; Omarchy rejects unsafe plugin folders.
- Test changes against a running Omarchy shell after static validation: `omarchy-shell shell rescanPlugins`.
- Review executable shell commands carefully: third-party plugins run unsandboxed inside `omarchy-shell`.
