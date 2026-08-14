# omarchy-sysinfo

CPU, per-core CPU, RAM, disk, temperature, and fan indicators for the Omarchy 4 bar.

Widget opens `btop` when clicked. Hovering CPU shows aggregate and per-core usage.

## Requirements

- Omarchy 4
- Quickshell shell with third-party plugin support
- Bash, `awk`, `df`, and standard `/proc`/`/sys` filesystems
- `btop` for click action

## Install

Review plugin source before installing: Omarchy plugins run arbitrary, unsandboxed code inside the long-lived shell process.

```bash
omarchy plugin add https://github.com/danielmrdev/omarchy-sysinfo.git --yes
omarchy plugin enable daniel.sysinfo --section right
```

If plugin is already enabled, reload the shell after updates:

```bash
omarchy-shell shell rescanPlugins
# If an old QML instance remains cached:
omarchy restart shell
```

Remove it with:

```bash
omarchy plugin remove daniel.sysinfo --yes
```

## Metrics

- CPU: aggregate usage percentage; warning/critical color thresholds at 60%/85%.
- CPU tooltip: aggregate usage plus live usage for each core.
- RAM: used percentage and used/total GiB.
- Disk: root filesystem usage percentage and used/total GiB.
- Temperature: `coretemp` package temperature.
- Fan: ThinkPad `fan1_input`/`fan2_input` RPM when available.

Metrics refresh every three seconds. Missing temperature or fan sensors report `0`.

## Development

From this directory:

```bash
omarchy plugin validate .
qmllint BarWidget.qml
bash -n sysinfo.sh
./sysinfo.sh
```

To test a local checkout without cloning it, copy or symlink the plugin into
`~/.config/omarchy/plugins/daniel.sysinfo/`, then rescan the shell.
