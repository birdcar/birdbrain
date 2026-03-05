#!/usr/bin/env python3
"""
Birdbrain folder picker — a Kitty kitten for browsing directories.
Runs inside Kitty using its embedded Python. Returns selected path to stdout.

Usage: kitty +kitten folder-picker.py [start_directory]
"""

import os
import sys
import tty
import termios


def get_folders(path):
    """List subdirectories in path, sorted alphabetically."""
    try:
        entries = []
        for name in sorted(os.listdir(path), key=str.lower):
            full = os.path.join(path, name)
            if os.path.isdir(full) and not name.startswith("."):
                entries.append(name)
        return entries
    except PermissionError:
        return []


def render(stdscr, cwd, folders, selected, scroll_offset, rows):
    """Render the folder picker UI."""
    # Clear screen
    sys.stdout.write("\033[2J\033[H")

    # Header
    sys.stdout.write("\033[1;35m  Birdbrain — Choose a folder\033[0m\n")
    sys.stdout.write("\033[90m  ─────────────────────────────\033[0m\n")

    # Current path
    home = os.path.expanduser("~")
    display_path = cwd.replace(home, "~") if cwd.startswith(home) else cwd
    sys.stdout.write(f"\033[1;34m  {display_path}/\033[0m\n\n")

    # Available rows for listing (header=4 lines, footer=3 lines)
    list_rows = rows - 7

    # Parent directory option
    items = ["..  (parent directory)"] + [f"📁 {f}" for f in folders]

    # Adjust scroll offset
    if selected < scroll_offset:
        scroll_offset = selected
    if selected >= scroll_offset + list_rows:
        scroll_offset = selected - list_rows + 1

    visible = items[scroll_offset : scroll_offset + list_rows]

    for i, item in enumerate(visible):
        idx = i + scroll_offset
        if idx == selected:
            sys.stdout.write(f"\033[1;32m  ▸ {item}\033[0m\n")
        else:
            sys.stdout.write(f"    {item}\n")

    # Scroll indicator
    if len(items) > list_rows:
        if scroll_offset > 0:
            sys.stdout.write("\033[90m    ↑ more\033[0m\n")
        elif scroll_offset + list_rows < len(items):
            sys.stdout.write("\033[90m    ↓ more\033[0m\n")
        else:
            sys.stdout.write("\n")
    else:
        sys.stdout.write("\n")

    # Footer
    sys.stdout.write("\n\033[90m  Enter: open  │  ← back  │  → enter folder  │  Esc: home dir\033[0m")
    sys.stdout.flush()

    return scroll_offset


def read_key():
    """Read a single keypress, handling escape sequences."""
    ch = sys.stdin.read(1)
    if ch == "\033":
        ch2 = sys.stdin.read(1)
        if ch2 == "[":
            ch3 = sys.stdin.read(1)
            if ch3 == "A":
                return "up"
            elif ch3 == "B":
                return "down"
            elif ch3 == "C":
                return "right"
            elif ch3 == "D":
                return "left"
            elif ch3 == "M":
                # Mouse click: read 3 more bytes
                btn = ord(sys.stdin.read(1)) - 32
                col = ord(sys.stdin.read(1)) - 32
                row = ord(sys.stdin.read(1)) - 32
                if btn == 0:  # left click
                    return ("click", row, col)
                return "mouse_other"
            return "escape"
        return "escape"
    elif ch == "\r" or ch == "\n":
        return "enter"
    elif ch == "q":
        return "quit"
    return ch


def get_terminal_size():
    try:
        cols, rows = os.get_terminal_size()
        return rows, cols
    except OSError:
        return 24, 80


def main():
    start_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~")
    if not os.path.isdir(start_dir):
        start_dir = os.path.expanduser("~")

    cwd = os.path.abspath(start_dir)
    selected = 0
    scroll_offset = 0

    # Save terminal state and enable raw mode
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        tty.setraw(fd)
        # Enable mouse tracking (basic mode)
        sys.stdout.write("\033[?1000h")
        # Hide cursor
        sys.stdout.write("\033[?25l")
        sys.stdout.flush()

        while True:
            rows, cols = get_terminal_size()
            folders = get_folders(cwd)
            # Clamp selected
            max_idx = len(folders)  # 0 = parent, 1..N = folders
            if selected > max_idx:
                selected = 0

            scroll_offset = render(None, cwd, folders, selected, scroll_offset, rows)

            key = read_key()

            if key == "up":
                selected = max(0, selected - 1)
            elif key == "down":
                selected = min(max_idx, selected + 1)
            elif key == "right" or key == "enter":
                if selected == 0:
                    # Parent directory
                    parent = os.path.dirname(cwd)
                    if parent != cwd:
                        cwd = parent
                        selected = 0
                        scroll_offset = 0
                elif key == "enter":
                    # Select this directory
                    chosen = os.path.join(cwd, folders[selected - 1])
                    # Restore terminal
                    sys.stdout.write("\033[?1000l\033[?25h\033[2J\033[H")
                    sys.stdout.flush()
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                    print(chosen)
                    return
                else:
                    # Right arrow: enter directory
                    cwd = os.path.join(cwd, folders[selected - 1])
                    selected = 0
                    scroll_offset = 0
            elif key == "left":
                parent = os.path.dirname(cwd)
                if parent != cwd:
                    cwd = parent
                    selected = 0
                    scroll_offset = 0
            elif key == "escape" or key == "quit":
                # Fall back to home
                sys.stdout.write("\033[?1000l\033[?25h\033[2J\033[H")
                sys.stdout.flush()
                termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                print(os.path.expanduser("~"))
                return
            elif isinstance(key, tuple) and key[0] == "click":
                # Map click row to item
                click_row = key[1]
                # Items start at row 5 (1-indexed: header=1, divider=2, path=3, blank=4)
                item_idx = click_row - 5 + scroll_offset
                if 0 <= item_idx <= max_idx:
                    selected = item_idx

    except Exception:
        # Ensure terminal is restored on any error
        sys.stdout.write("\033[?1000l\033[?25h\033[2J\033[H")
        sys.stdout.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        print(os.path.expanduser("~"))


if __name__ == "__main__":
    main()
