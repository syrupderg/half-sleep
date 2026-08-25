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

kbd_arg="$1"
vol_arg="$2"
prof_arg="$3"
block_arg="$4"

if kscreen-doctor -o | grep -q "Virtual-BlackHole"; then
    if [ -f /tmp/screen-toggle-inhibit.pid ]; then
        kill $(cat /tmp/screen-toggle-inhibit.pid) 2>/dev/null
        rm -f /tmp/screen-toggle-inhibit.pid
    fi
    if [ -f /tmp/screen-toggle-vol.txt ]; then
        saved_vol=$(cat /tmp/screen-toggle-vol.txt)
        set_vol "$saved_vol"
        rm -f /tmp/screen-toggle-vol.txt
    fi

    if [ -f /tmp/screen-toggle-prof.txt ]; then
        saved_prof=$(cat /tmp/screen-toggle-prof.txt)
        set_prof "$saved_prof"
        rm -f /tmp/screen-toggle-prof.txt
    fi

    PRIMARY_OUT=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print $3}' | grep -v 'Virtual-BlackHole' | head -n 1)
    if [ -z "$PRIMARY_OUT" ]; then
        PRIMARY_OUT="eDP-1"
    fi
    kscreen-doctor output."$PRIMARY_OUT".enable
    killall krfb-virtualmonitor
    
    if [ -f /tmp/screen-toggle-bl.txt ]; then
        saved_bl=$(cat /tmp/screen-toggle-bl.txt)
        brightnessctl --class=backlight set "$saved_bl"
        rm -f /tmp/screen-toggle-bl.txt
    fi
    
    if [ -f /tmp/screen-toggle-kbd.txt ]; then
        saved_kbd=$(cat /tmp/screen-toggle-kbd.txt)
        (
            echo $BASHPID > /tmp/screen-toggle-kbd.pid
            for i in {1..10}; do
                set_kbd "$saved_kbd"
                sleep 0.2
            done
            rm -f /tmp/screen-toggle-kbd.pid
        ) &
        rm -f /tmp/screen-toggle-kbd.txt
    fi

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
            nohup systemd-inhibit --what=sleep:idle --who="Half Sleep" --why="Screen is turned off" sleep infinity >/dev/null 2>&1 &
            echo $! > /tmp/screen-toggle-inhibit.pid
        fi
    fi

    if ! pidof krfb-virtualmonitor > /dev/null; then
        native_res=$(kscreen-doctor -o | grep -m 1 "Geometry" | grep -o '[0-9]\+x[0-9]\+')
        if [ -z "$native_res" ]; then
            native_res="1920x1080"
        fi
        krfb-virtualmonitor --name BlackHole --resolution "$native_res" &
    fi
    
    for i in {1..20}; do 
        if kscreen-doctor -o | grep -q "Virtual-BlackHole"; then break; fi
        sleep 0.2
    done
    
    PRIMARY_OUT=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/ {print $3}' | grep -v 'Virtual-BlackHole' | head -n 1)
    if [ -z "$PRIMARY_OUT" ]; then
        PRIMARY_OUT="eDP-1"
    fi
    kscreen-doctor output."$PRIMARY_OUT".disable
    
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
