import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "../../"
import "../reusables"

Item {
    id: root
    implicitWidth: 320
    implicitHeight: 300

    function s(val) {
        return typeof Scaler !== "undefined" ? Scaler.s(val) : val;
    }

    property real cornerRadius: Math.min(ThemeBackend.borderRadius, root.s(20))
    property real cardRadius: Math.min(ThemeBackend.borderRadius, root.s(12))
    property color baseColor: Qt.darker(ThemeBackend.surface0, 1.04)

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(10)

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: "󰓃"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(18)
                    color: ThemeBackend.sapphire
                }

                Text {
                    text: "Микшер приложений"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.text
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: (Audio.apps ? Audio.apps.length : 0) + " приложений"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                }
            }

            // App list
            ListView {
                id: appsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.s(8)
                model: Audio.apps

                Item {
                    anchors.centerIn: parent
                    visible: !Audio.apps || Audio.apps.length === 0
                    width: parent.width
                    height: root.s(120)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.s(8)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰖁"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(32)
                            color: ThemeBackend.surface2
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Нет активных аудиопотоков"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: ThemeBackend.overlay0
                        }
                    }
                }

                delegate: Rectangle {
                    id: appCard
                    width: appsList.width
                    height: root.s(64)
                    radius: root.cardRadius
                    color: ThemeBackend.surface0
                    border.width: 1
                    border.color: ThemeBackend.surface1

                    readonly property var node: modelData
                    readonly property int nodeVol: node && node.audio ? Math.round(node.audio.volume * 100) : 0
                    readonly property bool nodeMute: node && node.audio ? node.audio.muted : false
                    readonly property string appName: node ? Audio.getNodeAppName(node) : "Приложение"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(8)
                        spacing: root.s(4)

                        // Top row: name, volume %, mute button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(6)

                            Text {
                                text: "󰎆"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(13)
                                color: ThemeBackend.sapphire
                            }

                            Text {
                                Layout.fillWidth: true
                                text: appCard.appName
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(12)
                                font.weight: Font.Medium
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                            }

                            Text {
                                text: appCard.nodeMute ? "Muted" : (appCard.nodeVol + "%")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                color: appCard.nodeMute ? ThemeBackend.red : ThemeBackend.subtext0
                            }

                            Rectangle {
                                implicitWidth: root.s(22)
                                implicitHeight: root.s(22)
                                radius: root.s(6)
                                color: muteMa.containsMouse ? ThemeBackend.surface2 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: appCard.nodeMute ? "󰖁" : "󰕾"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(12)
                                    color: appCard.nodeMute ? ThemeBackend.red : ThemeBackend.text
                                }

                                MouseArea {
                                    id: muteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (appCard.node) Audio.toggleMute(appCard.node);
                                    }
                                }
                            }
                        }

                        // Bottom row: slider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(16)
                            radius: root.s(8)
                            color: ThemeBackend.surface1
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: root.s(8)
                                width: Math.max(0, Math.min(parent.width, parent.width * (appCard.nodeVol / 100.0)))
                                color: appCard.nodeMute ? ThemeBackend.surface2 : ThemeBackend.sapphire

                                Behavior on width { NumberAnimation { duration: 100 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function setFromPos(mouse) {
                                    let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)));
                                    if (appCard.node) {
                                        Audio.setVolume(appCard.node, pct);
                                    }
                                }
                                onClicked: (mouse) => setFromPos(mouse)
                                onPositionChanged: (mouse) => {
                                    if (pressed) setFromPos(mouse);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
