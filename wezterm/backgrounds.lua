local assets = require("assets")

local backgrounds_list = {
    {
        source={File=assets.wallpaper_cave,},
        height="Contain",
        width="Contain",
        horizontal_align="Center",
    },
    {
        source={Color="#FFFFFF"},
        opacity=0.0,
    },
}


local backgrounds = {
    backgrounds_list = backgrounds_list,

    toggle_background = function(window, pane)
        local overrides = window:get_config_overrides() or {}
        if not overrides.background then
            overrides.background = {backgrounds_list[2]}
        else
            overrides.background = nil
        end
        window:set_config_overrides(overrides)
    end
}

return backgrounds
