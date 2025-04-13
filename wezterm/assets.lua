local wezterm = require("wezterm")

local home_location = (os.getenv("HOME") or os.getenv("UserProfile") or "~") .. "/"
local config_location = home_location .. ".config/wezterm/"
local assets_folder = config_location .. "assets/"
local wallpaper_folder = assets_folder .. "wallpapers/"



local assets = {
    wallpaper_filepaths = function ()
        local wallpaper_filepaths = {}
        for i, path in ipairs(wezterm.read_dir(wallpaper_folder)) do
            wallpaper_filepaths[i] = path
            wezterm.log_info(path)
        end
        return wallpaper_filepaths
    end
}
return assets
