#!/usr/bin/env python3
import sys, os, signal, select, glob, subprocess

# Auto-inherit 'input' group via newgrp if not yet in current session groups
ev_nodes = sorted(glob.glob('/dev/input/event*'))
if ev_nodes:
    try:
        test_fd = os.open(ev_nodes[0], os.O_RDONLY)
        os.close(test_fd)
    except PermissionError:
        if 'HALF_SLEEP_NEWGRP' not in os.environ:
            os.environ['HALF_SLEEP_NEWGRP'] = '1'
            cmd_str = ' '.join([f'"{a}"' for a in [sys.executable] + sys.argv])
            os.execvp('newgrp', ['newgrp', 'input', '-c', cmd_str])

import evdev

PID_FILE = '/tmp/screen-toggle-kbd-grab.pid'

SPECIAL_KEYS = {
    'launch (1)': evdev.ecodes.KEY_PROG1,
    'launch (2)': evdev.ecodes.KEY_PROG2,
    'launch (3)': evdev.ecodes.KEY_PROG3,
    'launch (4)': evdev.ecodes.KEY_PROG4,
    'launch (a)': evdev.ecodes.KEY_PROG1,
    'launch (b)': evdev.ecodes.KEY_PROG2,
    'launch (c)': evdev.ecodes.KEY_PROG3,
    'launch (d)': evdev.ecodes.KEY_PROG4,
    'sleep': evdev.ecodes.KEY_SLEEP,
    'power': evdev.ecodes.KEY_POWER,
    'pause': evdev.ecodes.KEY_PAUSE,
    'print': evdev.ecodes.KEY_PRINT,
    'escape': evdev.ecodes.KEY_ESC,
    'esc': evdev.ecodes.KEY_ESC,
    'space': evdev.ecodes.KEY_SPACE,
    'tab': evdev.ecodes.KEY_TAB,
    'backtab': evdev.ecodes.KEY_TAB,
    'return': evdev.ecodes.KEY_ENTER,
    'enter': evdev.ecodes.KEY_ENTER,
    'backspace': evdev.ecodes.KEY_BACKSPACE,
    'delete': evdev.ecodes.KEY_DELETE,
    'insert': evdev.ecodes.KEY_INSERT,
    'home': evdev.ecodes.KEY_HOME,
    'end': evdev.ecodes.KEY_END,
    'pageup': evdev.ecodes.KEY_PAGEUP,
    'pagedown': evdev.ecodes.KEY_PAGEDOWN,
    'up': evdev.ecodes.KEY_UP,
    'down': evdev.ecodes.KEY_DOWN,
    'left': evdev.ecodes.KEY_LEFT,
    'right': evdev.ecodes.KEY_RIGHT,
    'audiomute': evdev.ecodes.KEY_MUTE,
    'volumemute': evdev.ecodes.KEY_MUTE,
    'audiolowervolume': evdev.ecodes.KEY_VOLUMEDOWN,
    'audioraisevolume': evdev.ecodes.KEY_VOLUMEUP,
    'audioplay': evdev.ecodes.KEY_PLAYPAUSE,
    'audiostop': evdev.ecodes.KEY_STOPCD,
    'audionext': evdev.ecodes.KEY_NEXTSONG,
    'audioprev': evdev.ecodes.KEY_PREVIOUSSONG,
}

MOD_KEYS = {
    'ctrl': {evdev.ecodes.KEY_LEFTCTRL, evdev.ecodes.KEY_RIGHTCTRL},
    'control': {evdev.ecodes.KEY_LEFTCTRL, evdev.ecodes.KEY_RIGHTCTRL},
    'alt': {evdev.ecodes.KEY_LEFTALT, evdev.ecodes.KEY_RIGHTALT},
    'shift': {evdev.ecodes.KEY_LEFTSHIFT, evdev.ecodes.KEY_RIGHTSHIFT},
    'meta': {evdev.ecodes.KEY_LEFTMETA, evdev.ecodes.KEY_RIGHTMETA},
    'super': {evdev.ecodes.KEY_LEFTMETA, evdev.ecodes.KEY_RIGHTMETA},
    'win': {evdev.ecodes.KEY_LEFTMETA, evdev.ecodes.KEY_RIGHTMETA},
}

MOD_CODE_TO_NAME = {}
for name, codes in MOD_KEYS.items():
    standard_name = 'ctrl' if 'ctrl' in name or 'control' in name else ('alt' if 'alt' in name else ('shift' if 'shift' in name else 'meta'))
    for c in codes:
        MOD_CODE_TO_NAME[c] = standard_name

def parse_single_shortcut(s):
    parts = [p.strip() for p in s.split('+')]
    mods = set()
    code = None
    for p in parts:
        low = p.lower()
        if low in MOD_KEYS:
            if 'ctrl' in low or 'control' in low: mods.add('ctrl')
            elif 'alt' in low: mods.add('alt')
            elif 'shift' in low: mods.add('shift')
            elif 'meta' in low or 'super' in low or 'win' in low: mods.add('meta')
        else:
            if low in SPECIAL_KEYS:
                code = SPECIAL_KEYS[low]
            else:
                cand = 'KEY_' + p.upper()
                if hasattr(evdev.ecodes, cand):
                    code = getattr(evdev.ecodes, cand)
    return mods, code

def get_half_sleep_applet_ids():
    ids = set()
    rc_applets = os.path.expanduser('~/.config/plasma-org.kde.plasma.desktop-appletsrc')
    if os.path.exists(rc_applets):
        try:
            curr_applet = None
            with open(rc_applets) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('[') and 'Applets][' in line:
                        parts = line.split('Applets][')
                        if len(parts) > 1:
                            curr_applet = parts[1].split(']')[0]
                    elif curr_applet and 'plugin=dev.syrupderg.half-sleep' in line:
                        ids.add(curr_applet)
        except Exception:
            pass
    return ids

def get_target_shortcuts():
    shortcuts = []
    # 1. From CLI argument --shortcut="..."
    for arg in sys.argv[1:]:
        if arg.startswith('--shortcut='):
            raw = arg[len('--shortcut='):].strip()
            for part in raw.split('\t'):
                part = part.strip()
                if part and part.lower() != 'none':
                    m, c = parse_single_shortcut(part)
                    if c is not None:
                        shortcuts.append((m, c))

    # 2. If none, read from kglobalshortcutsrc dynamically
    if not shortcuts:
        applet_ids = get_half_sleep_applet_ids()
        rc_path = os.path.expanduser('~/.config/kglobalshortcutsrc')
        if os.path.exists(rc_path):
            try:
                with open(rc_path) as f:
                    for line in f:
                        line_low = line.lower()
                        matches_applet = any(f'activate widget {aid}' in line for aid in applet_ids)
                        if matches_applet or 'half sleep' in line_low or 'half-sleep' in line_low:
                            val = line.split('=', 1)[1].split(',')[0]
                            for part in val.split('\t'):
                                part = part.strip()
                                if part and part.lower() != 'none':
                                    m, c = parse_single_shortcut(part)
                                    if c is not None:
                                        shortcuts.append((m, c))
            except Exception:
                pass

    # Default fallback to Launch (3) if nothing found
    if not shortcuts:
        shortcuts.append((set(), evdev.ecodes.KEY_PROG3))

    return shortcuts

def main():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE) as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            sys.exit(0)
        except (ValueError, OSError):
            try:
                os.remove(PID_FILE)
            except OSError:
                pass

    target_shortcuts = get_target_shortcuts()

    # Discover keyboard devices
    devices = []
    for p in sorted(glob.glob('/dev/input/event*')):
        try:
            dev = evdev.InputDevice(p)
            caps = dev.capabilities()
            if evdev.ecodes.EV_KEY in caps:
                k_set = set(caps[evdev.ecodes.EV_KEY])
                has_target = any(code in k_set for _, code in target_shortcuts)
                is_keyboard = (evdev.ecodes.KEY_A in k_set and evdev.ecodes.KEY_ENTER in k_set)
                has_safety = (evdev.ecodes.KEY_POWER in k_set or evdev.ecodes.KEY_SLEEP in k_set)
                if has_target or is_keyboard or has_safety:
                    dev.grab()
                    devices.append(dev)
        except Exception:
            pass

    if not devices:
        sys.exit(0)

    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    def release_all():
        for d in devices:
            try:
                d.ungrab()
                d.close()
            except Exception:
                pass
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except Exception:
                pass

    def signal_handler(signum, frame):
        release_all()
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGHUP, signal_handler)

    active_mods = set()

    try:
        while True:
            r, _, _ = select.select(devices, [], [], 1.0)
            for dev in r:
                try:
                    for ev in dev.read():
                        if ev.type == evdev.ecodes.EV_KEY:
                            if ev.code in MOD_CODE_TO_NAME:
                                mod_name = MOD_CODE_TO_NAME[ev.code]
                                if ev.value == 1:
                                    active_mods.add(mod_name)
                                elif ev.value == 0:
                                    active_mods.discard(mod_name)

                            if ev.value in (1, 2):
                                # Emergency safety keys
                                if ev.code in [evdev.ecodes.KEY_POWER, evdev.ecodes.KEY_SLEEP]:
                                    release_all()
                                    subprocess.Popen(['/home/syrup/.local/bin/toggle-screen.sh'], start_new_session=True)
                                    sys.exit(0)

                                # Check configured shortcuts
                                for target_mods, target_code in target_shortcuts:
                                    if ev.code == target_code and active_mods == target_mods:
                                        release_all()
                                        subprocess.Popen(['/home/syrup/.local/bin/toggle-screen.sh'], start_new_session=True)
                                        sys.exit(0)
                except OSError:
                    try:
                        devices.remove(dev)
                        dev.close()
                    except Exception:
                        pass
    finally:
        release_all()

if __name__ == '__main__':
    main()
