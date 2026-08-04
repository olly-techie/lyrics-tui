# lyrics-tui

Live synced lyrics for the currently playing track — rendered as big ASCII art right in your terminal.

Turn any terminal into a karaoke screen. As your music plays, the current line is drawn huge with `pyfiglet`, and the next line is shown dimmed below it so you can sing ahead.

## Features

- Real-time, timestamp-synced lyrics (LRC format from [LRCLIB](https://lrclib.net))
- Current line rendered as large ASCII art; next line shown dimmed below
- Auto font scaling — picks the biggest font that fits your terminal width, falls back gracefully instead of truncating
- Works with any player exposing MPRIS via [`playerctl`](https://github.com/altdesktop/playerctl) (Spotify, VLC, mpd, etc.)

## Requirements

- Python 3.8+
- [`playerctl`](https://github.com/altdesktop/playerctl) — reads the currently playing track and position
- A media player that exposes MPRIS (see the OS notes below)

## Installation

### 1. Install playerctl

**Linux (Debian / Ubuntu)**
```bash
sudo apt install playerctl
```

**Linux (Arch)**
```bash
sudo pacman -S playerctl
```

**Linux (Fedora)**
```bash
sudo dnf install playerctl
```

**Linux (openSUSE)**
```bash
sudo zypper install playerctl
```

**macOS**
```bash
brew install playerctl
```

> **Note:** `playerctl` relies on the MPRIS D-Bus interface, which is a Linux/BSD technology. On macOS and Windows most players do **not** expose MPRIS, so track detection may fail even though the package installs. Linux is the fully-supported platform.

**Windows**
There is no official `playerctl` build for Windows, and virtually no players expose MPRIS there. The lyric renderer code itself is portable, but track detection will not work out of the box. Linux (WSL/WSL2 included) is recommended.

### 2. Install the Python dependencies

Use a virtual environment (recommended):

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Or globally:

```bash
pip install syncedlyrics pyfiglet
```

## Usage

1. Start playing something in a player that supports MPRIS (Spotify, VLC, mpd, etc.)
2. Run the script:

```bash
python3 lyrics.py
```

Or, if executable:

```bash
./lyrics.py
```

That's it. The screen shows the current line in big ASCII art with the upcoming line dimmed below. Press `Ctrl+C` to stop.

If you see **"No player detected"**, verify something is playing and your player is reachable:

```bash
playerctl -l          # list detected players
playerctl metadata    # show current track info
```

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `No player detected. Is something playing?` | Confirm a supported player is running and MPRIS is enabled, then check `playerctl -l`. |
| `No synced lyrics found for this track.` | The track isn't in the LRCLIB database. Try a different player version/source — metadata spelling matters. |
| `Lyrics found but not in synced (LRC) format.` | LRCLIB returned only plain text, not timestamps. No way around it for that track. |
| Text overflows the terminal | Widen the terminal window; fonts auto-scale down to `mini` before any truncation. |

## How it works

1. Queries `playerctl` for the current artist, title, and playback position
2. Fetches synced LRC lyrics from LRCLIB
3. Parses timestamps and polls the position ~3x per second
4. Re-renders only when the current line changes, clearing the screen each time

## Contributing

PRs welcome. Keep it simple, one script, no heavy framework.

## License

[MIT](LICENSE)
