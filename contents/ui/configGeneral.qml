import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: page
    
    property bool inInputGroup: true

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            let out = (data["stdout"] || "").trim()
            page.inInputGroup = (out === "YES")
        }
    }

    Component.onCompleted: {
        executable.connectSource("bash -c 'id -Gn $USER | grep -qw input && echo YES || echo NO'")
    }
    
    property alias cfg_toggleKbd: toggleKbdCheckbox.checked
    property alias cfg_kbdBrightness: kbdSlider.value
    
    property alias cfg_toggleVol: toggleVolCheckbox.checked
    property alias cfg_volTarget: volSlider.value
    
    property alias cfg_toggleProfile: toggleProfileCheckbox.checked
    property alias cfg_profileTarget: profileSlider.value
    
    property alias cfg_blockSleep: blockSleepSwitch.checked
    
    property alias cfg_disablePointers: disablePointersSwitch.checked
    property alias cfg_disableKeyboard: disableKeyboardSwitch.checked

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        // Keyboard Settings
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            CheckBox {
                id: toggleKbdCheckbox
                text: i18n("Change keyboard backlight when screen is off")
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                opacity: toggleKbdCheckbox.checked ? 1.0 : 0.5
                enabled: toggleKbdCheckbox.checked

                Label {
                    text: i18n("Brightness:")
                }
                Slider {
                    id: kbdSlider
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 15
                    from: 0
                    to: 3
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    value: 0
                }
                Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (kbdSlider.value === 0) return i18n("Off")
                        if (kbdSlider.value === 1) return i18n("Low")
                        if (kbdSlider.value === 2) return i18n("Medium")
                        return i18n("High")
                    }
                }
            }
        }
        
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Volume Settings
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            CheckBox {
                id: toggleVolCheckbox
                text: i18n("Change system volume when screen is off")
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                opacity: toggleVolCheckbox.checked ? 1.0 : 0.5
                enabled: toggleVolCheckbox.checked

                Label {
                    text: i18n("Volume:")
                }
                Slider {
                    id: volSlider
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 15
                    from: 0
                    to: 100
                    stepSize: 1
                    value: 0
                }
                Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(volSlider.value) + "%"
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Power Profile Settings
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            CheckBox {
                id: toggleProfileCheckbox
                text: i18n("Change power profile when screen is off")
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                opacity: toggleProfileCheckbox.checked ? 1.0 : 0.5
                enabled: toggleProfileCheckbox.checked

                Label {
                    text: i18n("Profile:")
                }
                Slider {
                    id: profileSlider
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 15
                    from: 0
                    to: 2
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    value: 0
                }
                Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (profileSlider.value === 0) return i18n("Power Save")
                        if (profileSlider.value === 1) return i18n("Balanced")
                        return i18n("Performance")
                    }
                }
            }
        }
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Sleep Settings
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            Switch {
                id: blockSleepSwitch
                text: i18n("Block sleep and screen locking when screen is off")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Input Settings
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            
            Switch {
                id: disablePointersSwitch
                text: i18n("Disable touchpad and mouse when screen is off")
            }

            Switch {
                id: disableKeyboardSwitch
                text: i18n("Disable keyboard when screen is off")
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: !page.inInputGroup
                type: Kirigami.MessageType.Warning
                text: i18n("Disabling the keyboard or mouse requires your user account to be in the 'input' group:\nsudo usermod -aG input $USER\n(Log out and back in after running this command)")
            }
        }
    }
}
