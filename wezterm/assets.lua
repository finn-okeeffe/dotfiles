local home_location = (os.getenv("HOME") or os.getenv("UserProfile") or "~") .. "/"
local config_location = home_location .. ".config/wezterm/"
local assets_folder = config_location .. "assets/"

local assets = {
    wallpaper_cave = assets_folder .. "gruvbox-wallpaper-cave.png",
}
return assets
