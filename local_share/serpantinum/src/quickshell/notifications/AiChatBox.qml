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

    property var messages: [
        {
            role: "assistant",
            text: "Привет! Я твой персональный AI-ассистент на рабочем столе. Чем могу помочь?",
            time: "Сейчас"
        }
    ]
    property bool isThinking: false

    function sendMessage(text) {
        if (!text || text.trim() === "" || isThinking) return;
        let query = text.trim();
        let msgs = messages.slice(0);
        msgs.push({
            role: "user",
            text: query,
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        });
        messages = msgs;
        chatInput.text = "";
        isThinking = true;

        aiProc.queryText = query;
        let scriptPath = Quickshell.env("HOME") + "/.local/share/serpantinum/src/scripts/ai_assistant.py";
        aiProc.command = ["python3", scriptPath, query];
        aiProc.running = true;
    }

    function clearChat() {
        messages = [{
            role: "assistant",
            text: "Диалог очищен. Готов к новым вопросам!",
            time: "Сейчас"
        }];
    }

    Process {
        id: aiProc
        property string queryText: ""
        property string buffer: ""
        stdout: SplitParser {
            onRead: (data) => {
                aiProc.buffer += data + "\n";
            }
        }
        onExited: {
            root.isThinking = false;
            let resp = aiProc.buffer.trim();
            aiProc.buffer = "";
            if (!resp) resp = "Ответ не получен или запрос завершился таймаутом.";
            let msgs = root.messages.slice(0);
            msgs.push({
                role: "assistant",
                text: resp,
                time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
            });
            root.messages = msgs;
            Qt.callLater(() => chatListView.positionViewAtEnd());
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
                    text: "󱚣"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(18)
                    color: ThemeBackend.mauve
                }

                Text {
                    text: "AI Ассистент"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.text
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: root.s(28)
                    implicitHeight: root.s(28)
                    radius: root.s(8)
                    color: clrMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "󰃢"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: root.s(13)
                        color: ThemeBackend.subtext0
                    }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearChat()
                    }
                }
            }

            // Message list
            ListView {
                id: chatListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.s(10)
                model: root.messages

                delegate: ColumnLayout {
                    width: chatListView.width
                    spacing: root.s(3)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(6)
                        layoutDirection: modelData.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                        Rectangle {
                            implicitWidth: root.s(24)
                            implicitHeight: root.s(24)
                            radius: root.s(12)
                            color: modelData.role === "user" ? ThemeBackend.blue : ThemeBackend.mauve

                            Text {
                                anchors.centerIn: parent
                                text: modelData.role === "user" ? "" : "󱚣"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(12)
                                color: ThemeBackend.base
                            }
                        }

                        Text {
                            text: modelData.role === "user" ? "Вы" : "AI"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                            font.weight: Font.Bold
                            color: ThemeBackend.subtext0
                        }

                        Text {
                            text: modelData.time || ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            color: ThemeBackend.overlay0
                        }
                    }

                    Rectangle {
                        Layout.maximumWidth: chatListView.width * 0.92
                        Layout.preferredWidth: msgText.implicitWidth + root.s(20)
                        Layout.preferredHeight: msgText.implicitHeight + root.s(14)
                        Layout.alignment: modelData.role === "user" ? Qt.AlignRight : Qt.AlignLeft
                        radius: root.cardRadius
                        color: modelData.role === "user" ? ThemeBackend.surface1 : ThemeBackend.surface0
                        border.width: modelData.role === "assistant" ? 1 : 0
                        border.color: ThemeBackend.surface1

                        Text {
                            id: msgText
                            anchors.fill: parent
                            anchors.margins: root.s(8)
                            text: modelData.text || ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: ThemeBackend.text
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // Thinking indicator
            RowLayout {
                Layout.fillWidth: true
                visible: root.isThinking
                spacing: root.s(6)

                Text {
                    text: "󱚣"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(12)
                    color: ThemeBackend.mauve
                }

                Text {
                    text: "AI генерирует ответ..."
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.mauve
                }
            }

            // Bottom Input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(40)
                radius: root.cardRadius
                color: ThemeBackend.surface0
                border.width: chatInput.activeFocus ? 1 : 0
                border.color: ThemeBackend.mauve

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(6)
                    spacing: root.s(6)

                    TextInput {
                        id: chatInput
                        Layout.fillWidth: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        color: ThemeBackend.text
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !chatInput.text && !chatInput.activeFocus
                            text: "Задайте вопрос AI..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: ThemeBackend.overlay0
                        }

                        onAccepted: root.sendMessage(text)
                    }

                    Rectangle {
                        implicitWidth: root.s(28)
                        implicitHeight: root.s(28)
                        radius: root.s(8)
                        color: sndMa.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.1) : ThemeBackend.mauve

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(14)
                            color: ThemeBackend.base
                        }

                        MouseArea {
                            id: sndMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sendMessage(chatInput.text)
                        }
                    }
                }
            }
        }
    }
}
