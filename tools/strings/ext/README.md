Each file here defines `ENTRIES = [("KEY", "English", "Türkçe"), ...]`. `build_strings.py` merges them into `data/localization/strings.json`.
Use one file per workstream (e.g. `ws_d_espionage.py`) so parallel branches never conflict. Run `python3 tools/strings/build_strings.py` after editing.
