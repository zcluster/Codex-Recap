# Codex Recap

A small, local-first macOS app for finding Codex projects you recently worked on and reopening the right thread.

![Platform](https://img.shields.io/badge/macOS-13%2B-black)
![Architecture](https://img.shields.io/badge/Apple%20Silicon-arm64-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Groups local Codex threads by working directory.
- Shows projects active in the past 24 hours under **Recent**.
- Shows older projects under **Dormant**, newest first.
- Opens the latest project thread in Codex Desktop with one click.
- Supports persistent light and Codex-style dark themes.
- Uses a native macOS Liquid Glass-style material interface.
- Includes a persistent **Float on Top** switch for keeping the app above other windows.
- Reads local data only; no network requests, analytics, or account access.

## Requirements

- macOS 13 or later on Apple Silicon.
- Codex Desktop installed and signed in.
- At least one local Codex session on the Mac.

Codex Recap does not have its own login. It reads `~/.codex/state_5.sqlite` in read-only mode and opens threads using `codex://threads/<thread-id>`. If `CODEX_HOME` is set, that directory is used instead.

## Install

Download `Codex-Recap-macOS-arm64.zip` from the GitHub Releases page, unzip it, and move **Codex Recap.app** to Applications.

Release builds are currently unsigned. macOS may require you to right-click the app and choose **Open** the first time. Never bypass a warning if the downloaded checksum does not match `SHA256SUMS.txt` in the release.

## Build from source

The app has no third-party dependencies. Xcode Command Line Tools are sufficient.

```bash
git clone https://github.com/YOUR_USERNAME/codex-recap.git
cd codex-recap
./build_app.sh
open "dist/Codex Recap.app"
```

Create the release ZIP and checksum locally:

```bash
./package_release.sh
```

## Optional CLI

The repository also includes a zero-dependency Python CLI:

```bash
python3 codex_recent.py
python3 codex_recent.py --hours 48
python3 codex_recent.py --json
```

## Privacy and compatibility

See [PRIVACY.md](PRIVACY.md). Codex Recap relies on Codex Desktop's local SQLite schema and `codex://` URL handler. These are not documented as stable third-party APIs, so a future Codex update may require a compatibility update here.

## Disclaimer

Codex Recap is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by OpenAI. Codex and OpenAI are trademarks of their respective owner.

## License

[MIT](LICENSE)
