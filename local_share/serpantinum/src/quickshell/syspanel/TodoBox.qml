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

    property var todoList: []
    property string stateFilePath: Quickshell.env("HOME") + "/.local/state/serpantinum/todo.json"

    function loadTodos() {
        try {
            let content = todoFileView.text();
            if (content && content.trim().length > 0) {
                todoList = JSON.parse(content);
            } else {
                todoList = [];
            }
        } catch (e) {
            todoList = [];
        }
    }

    function saveTodos() {
        let jsonStr = JSON.stringify(todoList, null, 2);
        Quickshell.execDetached(["python3", "-c", 
            "import os, sys, json\n" +
            "path = os.path.expanduser('~/.local/state/serpantinum/todo.json')\n" +
            "os.makedirs(os.path.dirname(path), exist_ok=True)\n" +
            "with open(path, 'w', encoding='utf-8') as f:\n" +
            "    f.write(sys.argv[1])\n", jsonStr]);
    }

    function addTodo(text) {
        if (!text || text.trim() === "") return;
        let item = {
            id: Date.now().toString(),
            text: text.trim(),
            done: false,
            date: new Date().toLocaleDateString()
        };
        let updated = todoList.slice(0);
        updated.unshift(item);
        todoList = updated;
        saveTodos();
    }

    function toggleTodo(index) {
        if (index < 0 || index >= todoList.length) return;
        let updated = todoList.slice(0);
        updated[index].done = !updated[index].done;
        todoList = updated;
        saveTodos();
    }

    function removeTodo(index) {
        if (index < 0 || index >= todoList.length) return;
        let updated = todoList.slice(0);
        updated.splice(index, 1);
        todoList = updated;
        saveTodos();
    }

    FileView {
        id: todoFileView
        path: root.stateFilePath
        watchChanges: false
        onLoaded: root.loadTodos()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "mkdir -p ~/.local/state/serpantinum && touch ~/.local/state/serpantinum/todo.json"]);
        loadTodos();
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(10)

            // Header with stats
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: "󰄲"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(18)
                    color: ThemeBackend.mauve
                }

                Text {
                    text: "Список задач"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.text
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    radius: root.s(10)
                    color: ThemeBackend.surface1
                    implicitWidth: countText.implicitWidth + root.s(14)
                    implicitHeight: root.s(22)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: {
                            let doneCount = 0;
                            for (let i = 0; i < root.todoList.length; i++) {
                                if (root.todoList[i].done) doneCount++;
                            }
                            return doneCount + " / " + root.todoList.length;
                        }
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        font.weight: Font.Medium
                        color: ThemeBackend.subtext0
                    }
                }
            }

            // Input field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(38)
                radius: root.cardRadius
                color: ThemeBackend.surface0
                border.width: todoInput.activeFocus ? 1 : 0
                border.color: ThemeBackend.mauve

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(6)
                    spacing: root.s(6)

                    TextInput {
                        id: todoInput
                        Layout.fillWidth: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(13)
                        color: ThemeBackend.text
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !todoInput.text && !todoInput.activeFocus
                            text: "Добавить новую задачу..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            color: ThemeBackend.overlay0
                        }

                        onAccepted: {
                            if (text.trim() !== "") {
                                root.addTodo(text);
                                text = "";
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: root.s(26)
                        implicitHeight: root.s(26)
                        radius: root.s(7)
                        color: addMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.surface1

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(14)
                            color: addMa.containsMouse ? ThemeBackend.base : ThemeBackend.text
                        }

                        MouseArea {
                            id: addMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (todoInput.text.trim() !== "") {
                                    root.addTodo(todoInput.text);
                                    todoInput.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // Task list
            ListView {
                id: todoListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.s(6)
                model: root.todoList

                Item {
                    anchors.centerIn: parent
                    visible: root.todoList.length === 0
                    width: parent.width
                    height: root.s(120)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.s(8)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰄱"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(32)
                            color: ThemeBackend.surface2
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Нет активных задач"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: ThemeBackend.overlay0
                        }
                    }
                }

                delegate: Rectangle {
                    width: todoListView.width
                    height: root.s(40)
                    radius: root.cardRadius
                    color: modelData.done ? ThemeBackend.surface0 : (taskMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                    opacity: modelData.done ? 0.6 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        id: taskMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleTodo(index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(10)
                        anchors.rightMargin: root.s(10)
                        spacing: root.s(10)

                        // Checkbox icon
                        Rectangle {
                            implicitWidth: root.s(20)
                            implicitHeight: root.s(20)
                            radius: root.s(6)
                            color: modelData.done ? ThemeBackend.green : "transparent"
                            border.width: 1.5
                            border.color: modelData.done ? ThemeBackend.green : ThemeBackend.surface2

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.done
                                text: "󰅖"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(12)
                                color: ThemeBackend.base
                            }
                        }

                        // Task text
                        Text {
                            Layout.fillWidth: true
                            text: modelData.text || ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.strikeout: modelData.done
                            color: modelData.done ? ThemeBackend.subtext0 : ThemeBackend.text
                            elide: Text.ElideRight
                        }

                        // Delete button
                        Rectangle {
                            implicitWidth: root.s(22)
                            implicitHeight: root.s(22)
                            radius: root.s(6)
                            color: delMa.containsMouse ? ThemeBackend.red : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅗"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(13)
                                color: delMa.containsMouse ? ThemeBackend.base : ThemeBackend.overlay0
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeTodo(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
