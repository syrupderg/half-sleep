#!/bin/bash

if [ -f /tmp/screen-toggle-kbd.pid ]; then
    kill $(cat /tmp/screen-toggle-kbd.pid) 2>/dev/null
    rm -f /tmp/screen-toggle-kbd.pid
fi

get_kbd() {
    qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl.keyboardBrightness
}

set_kbd() {
    qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl.setKeyboardBrightnessSilent "$1"
}

get_vol() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}'
}

set_vol() {
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1"
}

get_prof() {
    powerprofilesctl get
}

set_prof() {
    powerprofilesctl set "$1"
}

disable_pointers() {
    # 1. Grab relative pointer devices at kernel level so no movement deltas enter KWin or kernel buffer
    ~/.local/bin/half-sleep-grab.py &

    # 2. Disable touchpad via global shortcuts daemon
    qdbus org.kde.kglobalaccel /component/org_kde_touchpadshortcuts_desktop org.kde.kglobalaccel.Component.invokeShortcut "DisableTouchpad" >/dev/null 2>&1

    # 3. Disable KWin InputDevices
    if [ ! -f /tmp/screen-toggle-pointers.txt ]; then
        disabled=()
        for dev in $(busctl --user tree org.kde.KWin 2>/dev/null | grep -o '/org/kde/KWin/InputDevice/event[0-9]\+'); do
            is_ptr=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice pointer 2>/dev/null)
            is_touch=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice touchpad 2>/dev/null)
            is_enabled=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice enabled 2>/dev/null)
            if [[ ("$is_ptr" == *"true"* || "$is_touch" == *"true"*) && "$is_enabled" == *"true"* ]]; then
                busctl --user set-property org.kde.KWin "$dev" org.kde.KWin.InputDevice enabled b false >/dev/null 2>&1
                disabled+=("$dev")
            fi
        done
        if [ ${#disabled[@]} -gt 0 ]; then
            printf "%s\n" "${disabled[@]}" > /tmp/screen-toggle-pointers.txt
        fi
    fi
}

enable_pointers() {
    # 1. Release kernel grab
    if [ -f /tmp/screen-toggle-grab.pid ]; then
        kill $(cat /tmp/screen-toggle-grab.pid) 2>/dev/null
        rm -f /tmp/screen-toggle-grab.pid
    fi
    killall half-sleep-grab.py 2>/dev/null

    # 2. Re-enable KWin InputDevices from recorded list
    if [ -f /tmp/screen-toggle-pointers.txt ]; then
        while IFS= read -r dev || [ -n "$dev" ]; do
            [ -n "$dev" ] && busctl --user set-property org.kde.KWin "$dev" org.kde.KWin.InputDevice enabled b true >/dev/null 2>&1
        done < /tmp/screen-toggle-pointers.txt
        rm -f /tmp/screen-toggle-pointers.txt
    fi

    # 3. Fallback: ensure no mouse/touchpad device was left disabled in KWin
    for dev in $(busctl --user tree org.kde.KWin 2>/dev/null | grep -o '/org/kde/KWin/InputDevice/event[0-9]\+'); do
        is_ptr=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice pointer 2>/dev/null)
        is_touch=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice touchpad 2>/dev/null)
        is_en=$(busctl --user get-property org.kde.KWin "$dev" org.kde.KWin.InputDevice enabled 2>/dev/null)
        if [[ ("$is_ptr" == *"true"* || "$is_touch" == *"true"*) && "$is_en" == *"false"* ]]; then
            busctl --user set-property org.kde.KWin "$dev" org.kde.KWin.InputDevice enabled b true >/dev/null 2>&1
        fi
    done

    # 4. Enable touchpad via global shortcuts daemon
    qdbus org.kde.kglobalaccel /component/org_kde_touchpadshortcuts_desktop org.kde.kglobalaccel.Component.invokeShortcut "EnableTouchpad" >/dev/null 2>&1
}

# Parse named arguments
kbd_arg=""
vol_arg=""
prof_arg=""
block_arg=""
ptr_arg=""
kbd_block_arg=""
shortcut_arg=""

for arg in "$@"; do
    case "$arg" in
        --kbd=*) kbd_arg="$arg" ;;
        --vol=*) vol_arg="$arg" ;;
        --prof=*) prof_arg="$arg" ;;
        --block-sleep|--no-block-sleep) block_arg="$arg" ;;
        --disable-pointers|--no-disable-pointers) ptr_arg="$arg" ;;
        --disable-keyboard|--no-disable-keyboard) kbd_block_arg="$arg" ;;
        --shortcut=*) shortcut_arg="$arg" ;;
    esac
done

if pidof krfb-virtualmonitor > /dev/null || kscreen-doctor -o | grep -q "Virtual-BlackHole"; then
    # 1. Primary output resolution (instant from cache or fallback)
    PRIMARY_OUT="eDP-1"
    if [ -f /tmp/screen-toggle-out.txt ]; then
        PRIMARY_OUT=$(cat /tmp/screen-toggle-out.txt 2>/dev/null || echo "eDP-1")
    fi
    [ -z "$PRIMARY_OUT" ] && PRIMARY_OUT="eDP-1"

    # 2. Restore screen backlight in parallel immediately so panel starts lighting up right away
    if [ -f /tmp/screen-toggle-bl.txt ]; then
        saved_bl=$(cat /tmp/screen-toggle-bl.txt)
        (
            for i in {1..5}; do
                brightnessctl --class=backlight set "$saved_bl" >/dev/null 2>&1
                sleep 0.2
            done
        ) &
        rm -f /tmp/screen-toggle-bl.txt
    fi

    # 3. ATOMIC DISPLAY SWITCH: Enable physical panel and disable BlackHole simultaneously in ONE call
    kscreen-doctor output."$PRIMARY_OUT".enable output."$PRIMARY_OUT".position.0,0 output."$PRIMARY_OUT".priority.1 output.Virtual-BlackHole.disable

    # 4. Release keyboard grabber and re-enable pointers IMMEDIATELY and SYNCHRONOUSLY
    if [ -f /tmp/screen-toggle-kbd-grab.pid ]; then
        kill $(cat /tmp/screen-toggle-kbd-grab.pid) 2>/dev/null
        rm -f /tmp/screen-toggle-kbd-grab.pid
    fi
    killall half-sleep-kbd.py 2>/dev/null
    enable_pointers

    # 5. Parallel background restoration (virtual monitor cleanup, volume, profile, inhibitor, kbd backlight)
    (
        killall krfb-virtualmonitor 2>/dev/null

        # Release sleep inhibitor
        if [ -f /tmp/screen-toggle-inhibit.pid ]; then
            kill $(cat /tmp/screen-toggle-inhibit.pid) 2>/dev/null
            rm -f /tmp/screen-toggle-inhibit.pid
        fi

        # Restore volume
        if [ -f /tmp/screen-toggle-vol.txt ]; then
            saved_vol=$(cat /tmp/screen-toggle-vol.txt)
            set_vol "$saved_vol"
            rm -f /tmp/screen-toggle-vol.txt
        fi

        # Restore power profile
        if [ -f /tmp/screen-toggle-prof.txt ]; then
            saved_prof=$(cat /tmp/screen-toggle-prof.txt)
            set_prof "$saved_prof"
            rm -f /tmp/screen-toggle-prof.txt
        fi

        # Restore keyboard backlight
        if [ -f /tmp/screen-toggle-kbd.txt ]; then
            saved_kbd=$(cat /tmp/screen-toggle-kbd.txt)
            echo $BASHPID > /tmp/screen-toggle-kbd.pid
            for i in {1..10}; do
                set_kbd "$saved_kbd"
                sleep 0.2
            done
            rm -f /tmp/screen-toggle-kbd.pid
            rm -f /tmp/screen-toggle-kbd.txt
        fi
    ) &

else
    current_bl=$(brightnessctl --class=backlight get)
    if [ ! -f /tmp/screen-toggle-bl.txt ]; then
        if [ "$current_bl" -gt 0 ]; then
            echo "$current_bl" > /tmp/screen-toggle-bl.txt
        fi
    fi

    if [[ "$kbd_arg" == --kbd=* ]] && [[ "$kbd_arg" != "--kbd=none" ]]; then
        pct="${kbd_arg#--kbd=}"
        current_kbd=$(get_kbd)
        
        # Avoid saving an already-muted brightness if toggled too fast
        if [ ! -f /tmp/screen-toggle-kbd.txt ]; then
            if [ "$current_kbd" -gt 0 ]; then
                echo "$current_kbd" > /tmp/screen-toggle-kbd.txt
            else
                echo "3" > /tmp/screen-toggle-kbd.txt
            fi
        fi
        
        max_kbd=$(qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl.keyboardBrightnessMax)
        target_kbd=$(( (max_kbd * pct + 50) / 100 ))
    fi

    if [[ "$vol_arg" == --vol=* ]] && [[ "$vol_arg" != "--vol=none" ]]; then
        vol_pct="${vol_arg#--vol=}"
        current_vol=$(get_vol)
        if [ ! -f /tmp/screen-toggle-vol.txt ]; then
            echo "$current_vol" > /tmp/screen-toggle-vol.txt
        fi
        set_vol "${vol_pct}%"
    fi

    if [[ "$prof_arg" == --prof=* ]] && [[ "$prof_arg" != "--prof=none" ]]; then
        target_prof="${prof_arg#--prof=}"
        current_prof=$(get_prof)
        if [ ! -f /tmp/screen-toggle-prof.txt ]; then
            echo "$current_prof" > /tmp/screen-toggle-prof.txt
        fi
        set_prof "$target_prof"
    fi

    if [[ "$block_arg" == "--block-sleep" ]]; then
        if [ ! -f /tmp/screen-toggle-inhibit.pid ]; then
            systemd-inhibit --what=sleep:idle --who="Half Sleep" --why="Screen is turned off" sleep infinity &
            echo $! > /tmp/screen-toggle-inhibit.pid
        fi
    fi

    if [[ "$ptr_arg" == "--disable-pointers" ]]; then
        disable_pointers &
    fi

    if [[ "$kbd_block_arg" == "--disable-keyboard" ]]; then
        if [ -n "$shortcut_arg" ]; then
            ~/.local/bin/half-sleep-kbd.py "$shortcut_arg" &
        else
            ~/.local/bin/half-sleep-kbd.py &
        fi
    fi

    if ! pidof krfb-virtualmonitor > /dev/null; then
        native_res=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | grep -m 1 "Geometry" | grep -o '[0-9]\+x[0-9]\+')
        if [ -z "$native_res" ]; then
            native_res="1920x1080"
        fi
        krfb-virtualmonitor --name BlackHole --resolution "$native_res" &
    fi
    
    PRIMARY_OUT=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print $3}' | grep -v 'Virtual-BlackHole' | head -n 1)
    if [ -z "$PRIMARY_OUT" ]; then
        PRIMARY_OUT="eDP-1"
    fi
    echo "$PRIMARY_OUT" > /tmp/screen-toggle-out.txt
    
    for i in {1..20}; do 
        if kscreen-doctor -o | grep -q "Virtual-BlackHole"; then
            kscreen-doctor output.Virtual-BlackHole.enable output.Virtual-BlackHole.position.0,0 output."$PRIMARY_OUT".disable >/dev/null 2>&1
            break
        fi
        sleep 0.05
    done
    
    if [[ "$kbd_arg" == --kbd=* ]] && [[ "$kbd_arg" != "--kbd=none" ]]; then
        (
            echo $BASHPID > /tmp/screen-toggle-kbd.pid
            for i in {1..15}; do
                set_kbd "$target_kbd"
                sleep 0.2
            done
            rm -f /tmp/screen-toggle-kbd.pid
        ) &
    fi
fi
