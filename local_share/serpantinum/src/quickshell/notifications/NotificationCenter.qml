import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/display"
import "../quickactions/actions" as QA

Item {
    id: root
    visible: false
    focus: true

    function s(val) { 
        return Scaler.s(val); 
    }

    property real introContent: 0.0

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    Timer {
        id: autoCloseTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root.visible && !mouseAreaHover.hovered) {
                if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
                    masterWindow.switchWidget("hidden", "");
                } else {
                    closeSequence.restart();
                }
            }
        }
    }

    HoverHandler {
        id: mouseAreaHover
        onHoveredChanged: {
            if (!hovered) {
                autoCloseTimer.restart();
            } else {
                autoCloseTimer.stop();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            startupSequence.restart();
            focusTimer.restart();
        } else {
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        if (visible) {
            startupSequence.start();
            focusTimer.start();
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: startupSequence
        NumberAnimation { 
            target: root
            property: "introContent"
            to: 1.0
            duration: 400
            easing.type: Easing.OutQuart
        } 
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { 
                target: root
                property: "introContent"
                to: 0.0
                duration: 240
                easing.type: Easing.InQuart
            }
        }
        ScriptAction { 
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            } 
        }    
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.97)
        radius: ThemeBackend.borderRadius
        border.width: 1
        border.color: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.9)
        clip: true
        opacity: root.introContent

        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: root.s(16)
            color: sidebarPanel.color
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: sidebarPanel.border.color }
        }

        Item {
            id: leftContentItem
            anchors.fill: parent
            anchors.margins: root.s(10)
            opacity: introContent
            scale: 0.96 + (0.04 * introContent)
            transform: Translate { y: root.s(40) * (1.0 - introContent) }

            property string activeLeftTab: "ai" // "ai", "trans", "notifs"

            ColumnLayout {
                anchors.fill: parent
                spacing: root.s(10)

                // Top navigation tab bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)

                    Repeater {
                        model: [
                            { id: "ai", icon: "󱚣", label: "AI", color: ThemeBackend.mauve },
                            { id: "trans", icon: "󰊿", label: "Перевод", color: ThemeBackend.teal },
                            { id: "draw", icon: "󰽉", label: "Рисовать", color: ThemeBackend.peach },
                            { id: "notes", icon: "󰈙", label: "Заметки", color: ThemeBackend.yellow },
                            { id: "timer", icon: "󰔛", label: "Таймер", color: ThemeBackend.blue },
                            { id: "sys", icon: "󰍛", label: "Система", color: ThemeBackend.green },
                            { id: "dock", icon: "󰍜", label: "Док", color: ThemeBackend.lavender }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(36)
                            radius: Math.min(ThemeBackend.borderRadius, root.s(10))
                            color: leftContentItem.activeLeftTab === modelData.id ? modelData.color : (tabMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: root.s(4)

                                Text {
                                    text: modelData.icon
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(14)
                                    color: leftContentItem.activeLeftTab === modelData.id ? ThemeBackend.base : ThemeBackend.text
                                }

                                Text {
                                    text: modelData.label
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: leftContentItem.activeLeftTab === modelData.id ? Font.Bold : Font.Medium
                                    font.pixelSize: root.s(10)
                                    color: leftContentItem.activeLeftTab === modelData.id ? ThemeBackend.base : ThemeBackend.text
                                    visible: parent.width > root.s(40)
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
                                    leftContentItem.activeLeftTab = modelData.id;
                                }
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        implicitWidth: root.s(36)
                        implicitHeight: root.s(36)
                        radius: Math.min(ThemeBackend.borderRadius, root.s(10))
                        color: clsMa.containsMouse ? ThemeBackend.red : ThemeBackend.surface0

                        Text {
                            anchors.centerIn: parent
                            text: "󰅗"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(14)
                            color: clsMa.containsMouse ? ThemeBackend.base : ThemeBackend.text
                        }

                        MouseArea {
                            id: clsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: closeSequence.restart()
                        }
                    }
                }

                // Active content
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AiChatBox {
                        anchors.fill: parent
                        visible: leftContentItem.activeLeftTab === "ai"
                    }

                    TranslatorBox {
                        anchors.fill: parent
                        visible: leftContentItem.activeLeftTab === "trans"
                    }

                    Loader {
                        anchors.fill: parent
                        active: leftContentItem.activeLeftTab === "draw"
                        visible: active
                        sourceComponent: QA.DrawAction {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: leftContentItem.activeLeftTab === "notes"
                        visible: active
                        sourceComponent: QA.Notes {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: leftContentItem.activeLeftTab === "timer"
                        visible: active
                        sourceComponent: QA.Timer {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: leftContentItem.activeLeftTab === "sys"
                        visible: active
                        sourceComponent: QA.SystemUsage {}
                    }

                    Loader {
                        anchors.fill: parent
                        active: leftContentItem.activeLeftTab === "dock"
                        visible: active
                        sourceComponent: QA.Dock {}
                    }
                }
            }
        }
    }
}
