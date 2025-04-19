local wezterm = require("wezterm")

local home_location = (os.getenv("HOME") or os.getenv("UserProfile") or "~") .. "/"
local config_location = home_location .. ".config/wezterm/"
local assets_folder = config_location .. "assets/"
local wallpaper_folder = assets_folder .. "wallpapers/"



local assets = {
    wallpapers = {
        dark_bench = wallpaper_folder .. "dark-bench.png",
        door = wallpaper_folder .. "door.png",
        great_wave_of_kanagawa_gruvbox = wallpaper_folder .. "great-wave-of-kanagawa-gruvbox.png",
        gruv_abstract_maze = wallpaper_folder .. "gruv-abstract-maze.png",
        gruvbox_astro = wallpaper_folder .. "gruvbox_astro.jpg",
        gruvbox_minimal_space = wallpaper_folder .. "gruvbox_minimal_space.png",
        gruvbox_wallpaper_cave = wallpaper_folder .. "gruvbox-wallpaper-cave.png",
        gruv = wallpaper_folder .. "gruv.jpg",
        gruv_portal_cake = wallpaper_folder .. "gruv-portal-cake.png",
        gruv_wallpaper_toradora_1 = wallpaper_folder .. "gruv-wallpaper-toradora-1.png",
        gruvy_night = wallpaper_folder .. "gruvy-night.jpg",
        moon = wallpaper_folder .. "moon.png",
        orbit = wallpaper_folder .. "orbit.png",
        red_moon = wallpaper_folder .. "red-moon.png",
        rocket = wallpaper_folder .. "rocket.png",
        starry_sky = wallpaper_folder .. "starry-sky.png",
        sunset = wallpaper_folder .. "sunset.png",
    }
}
return assets
