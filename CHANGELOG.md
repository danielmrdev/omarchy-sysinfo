# Changelog

Notable changes for each release are listed here.

## [1.1.0] - 2026-10-13

- Add an About page with plugin version and project links.
- Add English and Spanish translations with a persistent System / English / Español selector.
- Keep version out of the metrics hero.
- Reserve bar-widget width for three-digit CPU percentages to prevent layout shifts.
- Keep the product name `System Info` unchanged in both locales.

## [1.0.0] - 2026-10-06

Initial release.

- Add a CPU-percentage bar widget with threshold colors and a four-metric hover summary.
- Add a click-open system dashboard with per-core CPU, memory, mounted storage, temperature, and fan readings.
- Add a button to open or focus `btop`.
- Handle unavailable sensors and failed or slow storage queries without showing stale readings.
