import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page
    
    property alias cfg_toggleKbd: toggleKbdCheckbox.checked
    property alias cfg_kbdBrightness: kbdSlider.value
    
    property alias cfg_toggleVol: toggleVolCheckbox.checked
    property alias cfg_volTarget: volSlider.value
    
    property alias cfg_toggleProfile: toggleProfileCheckbox.checked
    property alias cfg_profileTarget: profileSlider.value

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
    }
}
