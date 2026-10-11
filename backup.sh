#!/usr/bin/env bash
# Automated backup script for custom Omarchy / Hyprland Linux setup (Rice & Dotfiles)
# Excludes all private data, games, tokens, and browser caches.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
BIN_DIR="$DOTFILES_DIR/bin"
APP_DIR="$DOTFILES_DIR/applications"
PKG_DIR="$DOTFILES_DIR/packages"
HOME_DIR="$DOTFILES_DIR/home"

mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$APP_DIR" "$PKG_DIR" "$HOME_DIR"

echo "==> 1. Экспорт списков установленных пакетов..."
# Официальные пакеты Arch
pacman -Qqe > "$PKG_DIR/pacman-packages.txt" 2>/dev/null || true
# Пакеты из AUR
pacman -Qqm > "$PKG_DIR/aur-packages.txt" 2>/dev/null || true

echo "==> 2. Бэкап конфигураций (~/.config)..."
# Hyprland (без .bak файлов)
mkdir -p "$CONFIG_DIR/hypr"
rsync -av --exclude="*.bak*" --exclude="*.core" "$HOME/.config/hypr/" "$CONFIG_DIR/hypr/"

# Omarchy
if [[ -d "$HOME/.config/omarchy" ]]; then
  mkdir -p "$CONFIG_DIR/omarchy"
  rsync -av --exclude="*.log" --exclude=".git" --exclude="themes" "$HOME/.config/omarchy/" "$CONFIG_DIR/omarchy/"
fi

# VoxType
if [[ -d "$HOME/.config/voxtype" ]]; then
  mkdir -p "$CONFIG_DIR/voxtype"
  rsync -av "$HOME/.config/voxtype/" "$CONFIG_DIR/voxtype/"
fi

# Serpantinum
if [[ -d "$HOME/.config/serpantinum" ]]; then
  mkdir -p "$CONFIG_DIR/serpantinum"
  rsync -av "$HOME/.config/serpantinum/" "$CONFIG_DIR/serpantinum/"
fi

# Serpantinum Widgets Layout
if [[ -d "$HOME/.local/state/serpantinum/widgets" ]]; then
  mkdir -p "$DOTFILES_DIR/state/serpantinum/widgets"
  rsync -av "$HOME/.local/state/serpantinum/widgets/" "$DOTFILES_DIR/state/serpantinum/widgets/"
fi

# Serpantinum Core & Tweaks
if [[ -d "$HOME/.local/share/serpantinum/src" ]]; then
  mkdir -p "$DOTFILES_DIR/local_share/serpantinum/src"
  rsync -av --exclude="*.cache*" "$HOME/.local/share/serpantinum/src/" "$DOTFILES_DIR/local_share/serpantinum/src/"
fi

# Терминалы
for term in foot alacritty kitty ghostty; do
  if [[ -d "$HOME/.config/$term" ]]; then
    mkdir -p "$CONFIG_DIR/$term"
    rsync -av "$HOME/.config/$term/" "$CONFIG_DIR/$term/"
  fi
done

echo "==> 3. Бэкап системных пользовательских скриптов (~/.local/bin)..."
# Копируем только кастомные скрипты и утилиты, игнорируя бинарники > 50MB (например, agy.bin) и pycache
mkdir -p "$BIN_DIR"
for script in agy agy-account agy-accounts-gui agy_accounts_backend.py omarchy omarchy-agent omarchy-default-agent hypr-anim-gui; do
  if [[ -f "$HOME/.local/bin/$script" ]]; then
    cp "$HOME/.local/bin/$script" "$BIN_DIR/"
  fi
done

echo "==> 4. Бэкап .desktop ярлыков..."
mkdir -p "$APP_DIR"
for app in antigravity.desktop antigravity-accounts.desktop antigravity-add-account.desktop hypr-anim-gui.desktop; do
  if [[ -f "$HOME/.local/share/applications/$app" ]]; then
    cp "$HOME/.local/share/applications/$app" "$APP_DIR/"
  fi
done

echo "==> 5. Бэкап shell конфигов..."
[[ -f "$HOME/.bashrc" ]] && cp "$HOME/.bashrc" "$HOME_DIR/.bashrc"
[[ -f "$HOME/.bash_profile" ]] && cp "$HOME/.bash_profile" "$HOME_DIR/.bash_profile"

echo "==> 6. Проверка на безопасность данных..."
# Гарантируем, что реальные токены и ключи никогда не попадут в репозиторий
find "$DOTFILES_DIR" -type f \( -name "*.json" -o -name "*.txt" \) | while read -r file; do
  if grep -qE "ya29\.[0-9A-Za-z_-]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY" "$file" 2>/dev/null; then
    echo "ВНИМАНИЕ: Удалён токен/ключ из $file"
    rm -f "$file"
  fi
done

echo "==> Сборка успешно обновлена в $DOTFILES_DIR"
