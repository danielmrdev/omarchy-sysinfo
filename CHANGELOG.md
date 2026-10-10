# Changelog

Notable changes for each release are listed here.

## [Unreleased]

- Read CPU temperature on AMD CPUs by also accepting the `k10temp`/`zenpower` hwmon sensors, not just Intel `coretemp`.
- Use the English placeholder "Not available" instead of "No disponible".

## [1.0.0] - 2026-10-06

Initial release.

- Add a CPU-percentage bar widget with threshold colors and a four-metric hover summary.
- Add a click-open system dashboard with per-core CPU, memory, mounted storage, temperature, and fan readings.
- Add a button to open or focus `btop`.
- Handle unavailable sensors and failed or slow storage queries without showing stale readings.
