import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    
    property bool hasShortcut: Plasmoid.globalShortcut !== undefined && Plasmoid.globalShortcut.toString() !== ""

    toolTipMainText: i18n("Half Sleep")
    toolTipSubText: hasShortcut ? i18n("Ready (Shortcut assigned)") : i18n("Action required: Assign a global shortcut!")

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            executable.disconnectSource(sourceName)
        }
    }

    function toggleScreen() {
        let pct = 0;
        if (Plasmoid.configuration.kbdBrightness === 1) pct = 33;
        else if (Plasmoid.configuration.kbdBrightness === 2) pct = 66;
        else if (Plasmoid.configuration.kbdBrightness === 3) pct = 100;
        
        let kbdArg = Plasmoid.configuration.toggleKbd ? "--kbd=" + pct : "--kbd=none";
        let volArg = Plasmoid.configuration.toggleVol ? "--vol=" + Plasmoid.configuration.volTarget : "--vol=none";
        
        let profStr = "none";
        if (Plasmoid.configuration.toggleProfile) {
            if (Plasmoid.configuration.profileTarget === 0) profStr = "power-saver";
            else if (Plasmoid.configuration.profileTarget === 1) profStr = "balanced";
            else profStr = "performance";
        }
        let profArg = "--prof=" + profStr;
        
        executable.connectSource("bash -c '~/.local/bin/toggle-screen.sh " + kbdArg + " " + volArg + " " + profArg + "; echo " + Date.now() + "'")
    }

    Plasmoid.onActivated: {
        if (!hasShortcut) return;
        toggleScreen()
    }

    Item {
        anchors.fill: parent
        
        Text {
            anchors.centerIn: parent
            text: hasShortcut ? "💤" : "❗"
            font.pixelSize: Math.min(parent.width, parent.height) * 0.8
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!hasShortcut) {
                    executable.connectSource("kdialog --sorry 'Safety Lock: You MUST assign a global shortcut to this widget (Right Click > Configure > Keyboard Shortcuts) before you can use it, otherwise you will not be able to turn your screen back on!'")
                } else {
                    toggleScreen()
                }
            }
        }
    }
}
