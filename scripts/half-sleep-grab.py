#!/usr/bin/env python3
import sys, os, signal, fcntl, select, glob

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

PID_FILE = '/tmp/screen-toggle-grab.pid'

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

    devices = []
    try:
        import evdev
        for p in sorted(glob.glob('/dev/input/event*')):
            try:
                dev = evdev.InputDevice(p)
                # Check for relative motion (mice)
                if evdev.ecodes.EV_REL in dev.capabilities():
                    dev.grab()
                    devices.append(dev)
                else:
                    dev.close()
            except Exception:
                pass
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
            except OSError:
                pass

    def handler(signum, frame):
        release_all()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handler)
    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGHUP, handler)

    try:
        while True:
            r, _, _ = select.select(devices, [], [], 1.0)
            for dev in r:
                try:
                    dev.read()
                except Exception:
                    pass
    finally:
        release_all()

if __name__ == '__main__':
    main()
