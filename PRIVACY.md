# Privacy

Codex Recap is local-only software.

## Data it reads

The app reads the local Codex thread index at `$CODEX_HOME/state_5.sqlite`, or `~/.codex/state_5.sqlite` when `CODEX_HOME` is not set. It queries only the fields needed to display project paths, thread titles, thread identifiers, activity times, and thread counts.

To show Codex-compatible running and unread badges, the app also reads local rollout logs and the `electron-thread-read-state-v1` value in `$CODEX_HOME/.codex-global-state.json`. These files are never modified or uploaded.

The database is opened with SQLite's read-only flag. Codex Recap does not modify Codex data.

## Data it sends

Codex Recap makes no network requests and contains no analytics, telemetry, advertising, or crash-reporting SDK. It does not request an OpenAI password, API key, session cookie, or OAuth token.

When a user clicks a project, the app asks macOS to open a local `codex://threads/<thread-id>` URL. The installed Codex Desktop app handles that URL under its own account and privacy settings.

## Local preferences

The selected light or dark theme is saved locally using standard macOS application preferences.
