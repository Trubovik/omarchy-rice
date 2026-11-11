#!/usr/bin/env bash
# Automated restoration script for custom Omarchy / Hyprland Linux setup
# Run this on a fresh machine to restore all configs, scripts, and packages.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Восстановление кастомного Linux (Omarchy)"
echo "=========================================="

# 1. Установка пакетов
if [[ -f "$DOTFILES_DIR/packages/pacman-packages.txt" ]]; then
  echo "==> 1. Установка официальных пакетов Arch..."
  sudo pacman -S --needed --noconfirm - < "$DOTFILES_DIR/packages/pacman-packages.txt" || true
fi

if [[ -f "$DOTFILES_DIR/packages/aur-packages.txt" ]] && command -v yay &>/dev/null; then
  echo "==> 2. Установка AUR пакетов через yay..."
  yay -S --needed --noconfirm - < "$DOTFILES_DIR/packages/aur-packages.txt" || true
fi

# 2. Раскладывание конфигураций
echo "==> 3. Восстановление ~/.config/..."
mkdir -p "$HOME/.config"
if [[ -d "$DOTFILES_DIR/config" ]]; then
  cp -r "$DOTFILES_DIR/config/"* "$HOME/.config/"
fi

# Восстановление состояния виджетов
if [[ -d "$DOTFILES_DIR/state/serpantinum/widgets" ]]; then
  echo "==> 3.1 Восстановление виджетов Serpantinum..."
  mkdir -p "$HOME/.local/state/serpantinum/widgets"
  cp -r "$DOTFILES_DIR/state/serpantinum/widgets/"* "$HOME/.local/state/serpantinum/widgets/"
fi

# Восстановление кастомизаций Serpantinum
if [[ -d "$DOTFILES_DIR/local_share/serpantinum/src" ]]; then
  echo "==> 3.2 Восстановление Serpantinum (движок и кастомизации)..."
  mkdir -p "$HOME/.local/share/serpantinum/src"
  cp -r "$DOTFILES_DIR/local_share/serpantinum/src/"* "$HOME/.local/share/serpantinum/src/"
fi

if [[ -d "$DOTFILES_DIR/local_share/serpantinum/bin" ]]; then
  mkdir -p "$HOME/.local/share/serpantinum/bin"
  cp -r "$DOTFILES_DIR/local_share/serpantinum/bin/"* "$HOME/.local/share/serpantinum/bin/"
  chmod +x "$HOME/.local/share/serpantinum/bin/"*
fi

if [[ -f "$DOTFILES_DIR/local_share/serpantinum/version.txt" ]]; then
  cp "$DOTFILES_DIR/local_share/serpantinum/version.txt" "$HOME/.local/share/serpantinum/"
fi

# 3. Восстановление скриптов в ~/.local/bin
echo "==> 4. Восстановление скриптов в ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
if [[ -d "$DOTFILES_DIR/bin" ]]; then
  cp -r "$DOTFILES_DIR/bin/"* "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/"*
fi
ln -sf "$HOME/.local/share/serpantinum/bin/serpantinum" "$HOME/.local/bin/serpantinum"
ln -sf "$HOME/.local/share/serpantinum/bin/serpantinumd" "$HOME/.local/bin/serpantinumd"

# 4. Восстановление .desktop файлов
echo "==> 5. Восстановление desktop-файлов..."
mkdir -p "$HOME/.local/share/applications"
if [[ -d "$DOTFILES_DIR/applications" ]]; then
  cp -r "$DOTFILES_DIR/applications/"* "$HOME/.local/share/applications/"
fi

# 5. Shell конфиги
echo "==> 6. Восстановление ~/.bashrc..."
if [[ -f "$DOTFILES_DIR/home/.bashrc" ]]; then
  cp "$DOTFILES_DIR/home/.bashrc" "$HOME/.bashrc"
fi
if [[ -f "$DOTFILES_DIR/home/.bash_profile" ]]; then
  cp "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
fi

echo "==> 7. Запуск службы Serpantinum Shell..."
if [[ -x "$HOME/.local/bin/serpantinumd" ]]; then
  "$HOME/.local/bin/serpantinumd" stop 2>/dev/null || true
  sleep 0.5
  "$HOME/.local/bin/serpantinumd" start 2>/dev/null &
fi

echo "=========================================="
echo "  Готово! Конфигурация успешно восстановлена."
echo "  Перезагрузите сессию Hyprland: hyprctl reload"
echo "=========================================="
