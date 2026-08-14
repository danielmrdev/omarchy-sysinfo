# Project Context

`omarchy-sysinfo` is a third-party Omarchy 4 bar widget showing CPU, per-core CPU, RAM, disk, temperature, and fan metrics.

## Tooling

- Runtime: Omarchy 4 / Quickshell QML.
- Data source: Bash, `/proc`, `/sys`, `df`, and `awk`.
- Validate manifest: `omarchy plugin validate .`
- Validate QML: `qmllint BarWidget.qml`
- Validate script: `bash -n sysinfo.sh`

## Guidance

- Keep plugin id `daniel.sysinfo` unless a migration is intentionally planned.
- Keep entry-point paths relative and symlink-free; Omarchy rejects unsafe plugin folders.
- Test changes against a running Omarchy shell after static validation: `omarchy-shell shell rescanPlugins`.
- Review executable shell commands carefully: third-party plugins run unsandboxed inside `omarchy-shell`.
