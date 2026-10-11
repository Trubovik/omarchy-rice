pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../singletons/system"

Scope {
    id: edgeTriggers

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData

            property var activeToplevel: ToplevelManager.activeToplevel
            property bool isFullscreenActive: {
                if (!activeToplevel || !activeToplevel.fullscreen) return false;
                if (activeToplevel.screens && activeToplevel.screens.length > 0) {
                    return activeToplevel.screens.indexOf(monitorScope.modelData) !== -1;
                }
                return true;
            }

            // Left Edge Trigger -> Opens Left Panel (AI Chat / Translator / Notifications)
            PanelWindow {
                screen: monitorScope.modelData
                visible: !monitorScope.isFullscreenActive
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "serpantinum:edgeTriggerLeft"

                anchors {
                    top: true
                    bottom: true
                    left: true
                }

                implicitWidth: 6

                Timer {
                    id: leftTriggerTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-c", "serpantinum msg open notifications"]);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: leftTriggerTimer.restart()
                    onExited: leftTriggerTimer.stop()
                }
            }

            // Right Edge Trigger -> Opens Right Panel (System Panel: Todo / Pomodoro / Mixer / Power)
            PanelWindow {
                screen: monitorScope.modelData
                visible: !monitorScope.isFullscreenActive
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "serpantinum:edgeTriggerRight"

                anchors {
                    top: true
                    bottom: true
                    right: true
                }

                implicitWidth: 6

                Timer {
                    id: rightTriggerTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-c", "serpantinum msg open system"]);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: rightTriggerTimer.restart()
                    onExited: rightTriggerTimer.stop()
                }
            }
        }
    }
}
