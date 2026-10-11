import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
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

    // Pomodoro states: "focus", "short_break", "long_break"
    property string mode: "focus"
    property int focusSeconds: 25 * 60
    property int shortBreakSeconds: 5 * 60
    property int longBreakSeconds: 15 * 60

    property int totalSeconds: focusSeconds
    property int secondsLeft: focusSeconds
    property bool isRunning: false
    property int completedCycles: 0

    readonly property color modeColor: {
        if (mode === "focus") return ThemeBackend.peach;
        if (mode === "short_break") return ThemeBackend.green;
        return ThemeBackend.sapphire;
    }

    readonly property string modeName: {
        if (mode === "focus") return "Фокус";
        if (mode === "short_break") return "Перерыв";
        return "Отдых";
    }

    function formatTime(secs) {
        let m = Math.floor(secs / 60);
        let s = secs % 60;
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    function setMode(newMode) {
        mode = newMode;
        isRunning = false;
        if (mode === "focus") totalSeconds = focusSeconds;
        else if (mode === "short_break") totalSeconds = shortBreakSeconds;
        else totalSeconds = longBreakSeconds;
        secondsLeft = totalSeconds;
    }

    function toggleRun() {
        isRunning = !isRunning;
        if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
    }

    function resetTimer() {
        isRunning = false;
        secondsLeft = totalSeconds;
    }

    function tick() {
        if (!isRunning) return;
        if (secondsLeft > 0) {
            secondsLeft--;
        } else {
            isRunning = false;
            if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
            Quickshell.execDetached(["notify-send", "-a", "Serpantinum", "Помодоро таймер", 
                mode === "focus" ? "Время фокуса завершено! Пора отдохнуть." : "Перерыв завершен! Время возвращаться к делу."]);

            if (mode === "focus") {
                completedCycles++;
                if (completedCycles % 4 === 0) setMode("long_break");
                else setMode("short_break");
            } else {
                setMode("focus");
            }
        }
    }

    Timer {
        id: timer
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: root.tick()
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(14)
            spacing: root.s(12)

            // Header & mode selector
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: "󱎫"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(18)
                    color: root.modeColor
                }

                Text {
                    text: "Pomodoro"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.text
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Циклы: " + root.completedCycles
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                }
            }

            // Mode tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(6)

                Repeater {
                    model: [
                        { id: "focus", label: "Фокус (25м)" },
                        { id: "short_break", label: "Короткий (5м)" },
                        { id: "long_break", label: "Длинный (15м)" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(28)
                        radius: root.cardRadius
                        color: root.mode === modelData.id ? root.modeColor : (tabMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            font.weight: root.mode === modelData.id ? Font.Bold : Font.Normal
                            color: root.mode === modelData.id ? ThemeBackend.base : ThemeBackend.text
                        }

                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setMode(modelData.id)
                        }
                    }
                }
            }

            // Big Clock Display Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.cardRadius
                color: ThemeBackend.surface0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: root.s(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.formatTime(root.secondsLeft)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(42)
                        font.weight: Font.Black
                        color: root.modeColor
                    }

                    // Progress bar
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: root.s(220)
                        implicitHeight: root.s(6)
                        radius: root.s(3)
                        color: ThemeBackend.surface1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            radius: root.s(3)
                            color: root.modeColor
                            width: root.totalSeconds > 0 ? parent.width * (1.0 - (root.secondsLeft / root.totalSeconds)) : 0

                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.modeName + " • " + (root.isRunning ? "Идет таймер" : "На паузе")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        color: ThemeBackend.overlay0
                    }
                }
            }

            // Controls
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: root.s(12)

                Item { Layout.fillWidth: true }

                // Reset button
                Rectangle {
                    implicitWidth: root.s(42)
                    implicitHeight: root.s(42)
                    radius: root.s(12)
                    color: rstMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: root.s(18)
                        color: ThemeBackend.text
                    }

                    MouseArea {
                        id: rstMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetTimer()
                    }
                }

                // Play / Pause button
                Rectangle {
                    implicitWidth: root.s(100)
                    implicitHeight: root.s(42)
                    radius: root.s(12)
                    color: plyMa.containsMouse ? Qt.lighter(root.modeColor, 1.1) : root.modeColor

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: root.isRunning ? "󰏤" : "󰐊"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(16)
                            color: ThemeBackend.base
                        }

                        Text {
                            text: root.isRunning ? "Пауза" : "Старт"
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: root.s(13)
                            color: ThemeBackend.base
                        }
                    }

                    MouseArea {
                        id: plyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRun()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
