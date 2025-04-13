local assets = require("assets")
local wezterm = require("wezterm")


local backgrounds = {
    backgrounds_list = function ()
        local backgrounds = {}
        for index, filepath in ipairs(assets.wallpaper_filepaths()) do
            -- wezterm.log_info("Processing wallpaper " .. filepath)
            backgrounds[index] = {{
                source={File=filepath,},
                height="Contain",
                width="Contain",
                horizontal_align="Left",
            }}
        end
        return backgrounds
    end,
    plain_background = {{
        source={Color="black"},
        width="100%",
        height="100%",
        opacity=1.0
    }}
}

return backgrounds
