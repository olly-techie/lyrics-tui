#!/usr/bin/env python3
import subprocess
import time
import re
import shutil
import pyfiglet
import syncedlyrics


def get_current_track():
    artist = subprocess.run(
        ["playerctl", "metadata", "artist"], capture_output=True, text=True
    ).stdout.strip()
    title = subprocess.run(
        ["playerctl", "metadata", "title"], capture_output=True, text=True
    ).stdout.strip()
    return artist, title


def get_position():
    result = subprocess.run(["playerctl", "position"], capture_output=True, text=True)
    try:
        return float(result.stdout.strip())
    except ValueError:
        return 0.0


def parse_lrc(lrc_text):
    pattern = re.compile(r"\[(\d+):(\d+\.\d+)\](.*)")
    lines = []
    for line in lrc_text.splitlines():
        m = pattern.match(line)
        if m:
            minutes, seconds, text = m.groups()
            ts = int(minutes) * 60 + float(seconds)
            lines.append((ts, text.strip()))
    return sorted(lines)


def get_current_and_next(pos, lines):
    current, nxt = "", ""
    for i, (ts, text) in enumerate(lines):
        if ts <= pos:
            current = text
            nxt = lines[i + 1][1] if i + 1 < len(lines) else ""
        else:
            break
    return current, nxt


# Measured chars-of-rendered-width per input char, per font (via pyfiglet test render)
FONT_WIDTH_FACTOR = {
    "slant": 2.7,
    "small": 3.55,
    "mini": 2.25,
}


def pick_font(text, cols):
    """
    Pick the largest font that will still fit the line on screen,
    falling back to smaller fonts for longer lines instead of
    truncating text.
    """
    for font in ("slant", "small", "mini"):
        factor = FONT_WIDTH_FACTOR[font]
        if len(text) * factor <= cols:
            return font
    return "mini"  # smallest option, may still be tight on very long lines


def fit_text(text, cols, font):
    """
    Safety net only — trims text if even the smallest font would
    overflow the terminal width. Shouldn't trigger for normal lyric
    line lengths on a reasonably sized terminal.
    """
    factor = FONT_WIDTH_FACTOR[font]
    max_chars = max(1, int(cols / factor))
    if len(text) > max_chars:
        return text[: max_chars - 1] + "…"
    return text


def render(current, nxt):
    cols = shutil.get_terminal_size().columns
    print("\033[2J\033[H", end="")  # clear screen, move cursor home

    if current:
        font = pick_font(current, cols)
        fitted = fit_text(current, cols, font)
        fig = pyfiglet.Figlet(font=font, width=cols)
        print("\033[97m" + fig.renderText(fitted) + "\033[0m")
    else:
        print("\n" * 3)

    print("\033[2m" + nxt.center(cols) + "\033[0m")


def main():
    artist, title = get_current_track()
    if not artist and not title:
        print("No player detected. Is something playing? Run: playerctl -l")
        return

    print(f"Fetching lyrics for {title} - {artist}...")
    lrc = syncedlyrics.search(f"{title} {artist}", providers=["Lrclib"])

    if not lrc or "[" not in lrc:
        print("No synced lyrics found for this track.")
        return

    lines = parse_lrc(lrc)
    if not lines:
        print("Lyrics found but not in synced (LRC) format.")
        return

    last_current = None
    try:
        while True:
            pos = get_position()
            current, nxt = get_current_and_next(pos, lines)
            if current != last_current:
                render(current, nxt)
                last_current = current
            time.sleep(0.3)
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
