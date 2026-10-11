-- Change the default Omarchy look'n'feel.

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 10,
    border_size = 2,
  },
  decoration = {
    rounding = 12,
    dim_inactive = true,
    dim_strength = 0.08,
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      new_optimizations = true,
    },
  },
})

-- Terminal transparency and blur rule
o.window({ class = "^(foot|footclient|kitty|Alacritty|ghostty)$" }, {
  opacity = 0.88,
})

-- Custom animation loader
local anim_path = (os.getenv("HOME") or "/home/trubovik") .. "/.config/hypr/animations/current.lua"
local f = io.open(anim_path, "r")
if f then
  f:close()
  dofile(anim_path)
end
