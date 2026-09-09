# Half Sleep

A KDE Plasma 6 widget that puts your laptop into a "half-sleep" state. It completely turns off your main laptop display (ignoring accidental mouse and keyboard inputs) while safely keeping your background applications (like music, downloads, or servers) fully running.

## How it Works
KDE Plasma natively prevents you from turning off your final remaining monitor to prevent you from getting permanently locked out of your system. 

This widget safely bypasses that restriction using a **"Virtual BlackHole" Hack**:
1. When clicked, it spawns an invisible, headless virtual monitor in the background (`krfb-virtualmonitor`).
2. Once KDE detects the virtual monitor, the script safely instructs `kscreen-doctor` to completely disable your main laptop screen (`eDP-1`).
3. Since your screen is technically disabled, any accidental trackpad brushes or keyboard bumps won't wake up the screen.
4. When you trigger your assigned global shortcut again, it enables your laptop screen and destroys the virtual monitor!

Additionally, the widget allows you to configure:
- **Disable Mouse & Touchpad**: Swallows all mouse movement deltas and turns off the touchpad so bumped mice or cats won't move your cursor while the display is dark.
- **Disable Keyboard**: Grabs keyboard input devices while the screen is off to ignore accidental keypresses, while keeping your assigned global shortcut (or physical Power button) active to wake the screen back up.
- **Sleep & Lock Inhibitor**: Keeps your system awake and unlocked even when the display is turned off.
- **Keyboard Backlight**: Intercepts PowerDevil and forces your keyboard backlight to stay exactly at the level you configure (using `brightnessctl`).
- **System Volume**: Drops your volume to a safe level while the screen is off (using `wpctl`).
- **Power Profile**: Automatically drops your CPU into power-saver mode while the screen is off, and restores performance when you wake it up (using `powerprofilesctl`).

## Dependencies
You will need the following standard Linux utilities installed:
* `krfb-virtualmonitor` (usually provided by the `krfb` package)
* `kscreen-doctor` (usually provided by `libkscreen` / `kscreen`)
* `brightnessctl` (for screen and keyboard backlight control)
* `wpctl` (WirePlumber, standard on modern Plasma 6 for volume control)
* `powerprofilesctl` (provided by `power-profiles-daemon`)
* `python-evdev` (package `python-evdev`, required if enabling keyboard or mouse grabbing)

## Installation

1. **Install the Widget:** <br>
   Clone or download this repository, then use `kpackagetool6` to install the plasmoid into your local KDE directory:
   ```bash
   kpackagetool6 -i .
   ```
   *(If you are updating an existing installation, use `kpackagetool6 -u .` instead)*

2. **Install the Backend Scripts:** <br>
   The widget relies on backend scripts to do the heavy lifting. Copy them to your local binaries folder:
   ```bash
   mkdir -p ~/.local/bin/
   cp scripts/* ~/.local/bin/
   chmod +x ~/.local/bin/toggle-screen.sh ~/.local/bin/half-sleep-grab.py ~/.local/bin/half-sleep-kbd.py
   ```

> [!IMPORTANT]
> **Keyboard & Mouse Disabling Permission:**
> If you plan to enable the options to disable keyboard or mouse inputs while the display is off, your user account must have permission to access Linux `/dev/input/event*` devices without root. Add your user to the `input` group:
> ```bash
> sudo usermod -aG input $USER
> ```
> After running this command, **log out and log back in** (or reboot) for group changes to take effect. If you skip this, Half Sleep will still work normally to turn your screen off and on, but keyboard and mouse inputs won't be blocked.

3. **Restart Plasma:** <br>
   Restart your desktop shell so KDE recognizes the new widget:
   ```bash
   systemctl restart --user plasma-plasmashell
   ```

4. **Add to Panel & Assign Shortcut:** <br>
   Right-click your KDE panel, select **Add Widgets**, search for **"Half Sleep"**, and add it.

> [!CAUTION]
> You must assign a global shortcut to the widget before it will let you turn off the screen.
