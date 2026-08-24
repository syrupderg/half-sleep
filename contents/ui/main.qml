import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    
    property bool hasShortcut: Plasmoid.globalShortcut !== undefined && Plasmoid.globalShortcut.toString() !== ""

    toolTipMainText: root.hasShortcut ? i18n("Turn Off Screen") : i18n("Safety Lock Active")
    toolTipSubText: root.hasShortcut ? i18n("Click to turn off the display") : i18n("You must assign a global shortcut to this widget before you can use it.")

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
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
        toggleScreen()
    }

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large

        Text {
            anchors.centerIn: parent
            text: root.hasShortcut ? "💤" : "❗"
            font.pixelSize: Math.min(parent.width, parent.height) * 0.7
            renderType: Text.NativeRendering
            opacity: mouseArea.pressed ? 0.7 : 1.0

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.hasShortcut) {
                        toggleScreen()
                    } else {
                        executable.connectSource("bash -c 'kdialog --sorry \"Safety Lock Active!\\n\\nYou must right-click the widget and assign a keyboard shortcut to \\\"Activate Widget\\\" first.\\n\\nIf you turned off the screen right now, you would have no way to turn it back on!\"'")
                    }
                }
            }
        }
    }
}
