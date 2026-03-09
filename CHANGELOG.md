## [1.3.2-alpha.1] - 2026-03-09

### Fixed

- Fix library load order: AceGUI-3.0 now loads before AceConfig-3.0 in the TOC file. This fixes "Cannot find a library instance of AceConfigDialog-3.0" error when no other addon provides AceGUI earlier in load order.
