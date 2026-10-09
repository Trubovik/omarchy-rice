-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Unbind existing SUPER + B if set
hl.unbind("SUPER + B")

-- Launch Google Chrome with clean Wayland/GPU environment
o.bind("SUPER + B", "Google Chrome", { launch = "google-chrome-stable" })

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Ensure user local bin is prioritized for keybindings and dispatchers
local local_bin = (os.getenv("HOME") or "/home/trubovik") .. "/.local/bin"
local current_path = os.getenv("PATH") or ""
if not current_path:find(local_bin, 1, true) then
  hl.env("PATH", local_bin .. ":" .. current_path)
end

-- Override default Agent binding to use user-level agent launcher wrapper
hl.unbind("SUPER + SHIFT + CTRL + A")
o.bind("SUPER + SHIFT + CTRL + A", "Agent", local_bin .. "/omarchy-agent --pick")
o.bind("SUPER + A", "Antigravity Agent", local_bin .. "/omarchy-agent")
o.bind("SUPER + ALT + A", "Rotate Antigravity Account", local_bin .. "/agy-account next")
o.bind("SUPER + CTRL + A", "Antigravity Accounts Dashboard", local_bin .. "/agy-accounts-gui")

-- Logitech G502: Button G4 (mouse:275) -> Push-to-talk voice dictation
o.bind("mouse:275", "Start dictation (G4 push-to-talk)", "voxtype record start")
o.bind("mouse:275", "Stop dictation (G4 push-to-talk)", "voxtype record stop", { release = true })

