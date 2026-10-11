import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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

    property string sourceLang: "auto"
    property string targetLang: "auto"
    property string translatedResult: ""
    property bool isTranslating: false

    function doTranslate() {
        let text = srcInput.text.trim();
        if (!text) {
            translatedResult = "";
            return;
        }
        isTranslating = true;
        let scriptPath = Quickshell.env("HOME") + "/.local/share/serpantinum/src/scripts/translate.py";
        translateProc.command = ["python3", scriptPath, text, sourceLang, targetLang];
        translateProc.running = true;
    }

    function copyResult() {
        if (!translatedResult) return;
        Quickshell.execDetached(["wl-copy", translatedResult]);
        if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
    }

    Process {
        id: translateProc
        property string buffer: ""
        stdout: SplitParser {
            onRead: (data) => {
                translateProc.buffer += data + "\n";
            }
        }
        onExited: {
            root.isTranslating = false;
            root.translatedResult = translateProc.buffer.trim();
            translateProc.buffer = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(14)
            spacing: root.s(10)

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: "󰊿"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(18)
                    color: ThemeBackend.teal
                }

                Text {
                    text: "Переводчик"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.text
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    radius: root.s(8)
                    color: ThemeBackend.surface1
                    implicitWidth: langLabel.implicitWidth + root.s(14)
                    implicitHeight: root.s(24)

                    Text {
                        id: langLabel
                        anchors.centerIn: parent
                        text: "RU ⇄ EN (Авто)"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        color: ThemeBackend.subtext0
                    }
                }
            }

            // Source Input Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.s(100)
                radius: root.cardRadius
                color: ThemeBackend.surface0
                border.width: srcInput.activeFocus ? 1 : 0
                border.color: ThemeBackend.teal

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(8)
                    spacing: root.s(4)

                    TextArea {
                        id: srcInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        color: ThemeBackend.text
                        wrapMode: Text.Wrap
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            visible: !srcInput.text && !srcInput.activeFocus
                            text: "Введите текст для перевода..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: ThemeBackend.overlay0
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: transBtnText.implicitWidth + root.s(20)
                            implicitHeight: root.s(26)
                            radius: root.s(8)
                            color: transMa.containsMouse ? Qt.lighter(ThemeBackend.teal, 1.1) : ThemeBackend.teal

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: root.s(4)

                                Text {
                                    text: root.isTranslating ? "󰑓" : "󰊿"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.base
                                }

                                Text {
                                    id: transBtnText
                                    text: root.isTranslating ? "Перевод..." : "Перевести"
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: root.s(11)
                                    color: ThemeBackend.base
                                }
                            }

                            MouseArea {
                                id: transMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.doTranslate()
                            }
                        }
                    }
                }
            }

            // Target Result Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.s(100)
                radius: root.cardRadius
                color: ThemeBackend.surface0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(8)
                    spacing: root.s(4)

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: resultText.implicitHeight
                        clip: true

                        Text {
                            id: resultText
                            width: parent.width
                            text: root.translatedResult || (root.isTranslating ? "Переводим текст..." : "Здесь появится результат перевода...")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: root.translatedResult ? ThemeBackend.text : ThemeBackend.overlay0
                            wrapMode: Text.Wrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.translatedResult.length > 0
                            implicitWidth: copyBtnText.implicitWidth + root.s(18)
                            implicitHeight: root.s(26)
                            radius: root.s(8)
                            color: copyMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: root.s(4)

                                Text {
                                    text: "󰆏"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.text
                                }

                                Text {
                                    id: copyBtnText
                                    text: "Скопировать"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(11)
                                    color: ThemeBackend.text
                                }
                            }

                            MouseArea {
                                id: copyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyResult()
                            }
                        }
                    }
                }
            }
        }
    }
}
