#!/usr/bin/env bash
clear
echo "=== Обновление Serpantinum ==="
echo ""
bash -c 'eval "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"'

# Автовосстановление EdgeTriggers для боковых панелей
WIDGETS_QMLDIR="$HOME/.local/share/serpantinum/src/quickshell/widgets/qmldir"
MAIN_QMLDIR="$HOME/.local/share/serpantinum/src/quickshell/qmldir"
SHELL_QML="$HOME/.local/share/serpantinum/src/quickshell/Shell.qml"

if [ -f "$WIDGETS_QMLDIR" ] && ! grep -q "EdgeTriggers" "$WIDGETS_QMLDIR"; then
    echo "EdgeTriggers 1.0 EdgeTriggers.qml" >> "$WIDGETS_QMLDIR"
fi
if [ -f "$MAIN_QMLDIR" ] && ! grep -q "EdgeTriggers" "$MAIN_QMLDIR"; then
    echo "EdgeTriggers 1.0 widgets/EdgeTriggers.qml" >> "$MAIN_QMLDIR"
fi
if [ -f "$SHELL_QML" ] && ! grep -q "EdgeTriggers" "$SHELL_QML"; then
    sed -i '/Idle {}/a \    EdgeTriggers {}' "$SHELL_QML"
fi

serpantinumd stop && sleep 1 && serpantinumd start
echo "=== Serpantinum успешно обновлен и перезапущен ==="

