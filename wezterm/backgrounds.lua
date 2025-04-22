local assets = require("assets")
local wezterm = require("wezterm")


local backgrounds = {
    backgrounds_list = {
        -- Dark bench
        {
            {
                source={Color="#292929"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.dark_bench},
                width=1920,
                height=1080,
                horizontal_align="Center",
                vertical_align="Middle",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
            },
        },

        -- Door
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.door},
                width=404,
                height=654,
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Right",
                vertical_align="Middle",
            },
        },

        -- Great wave
        {
            {
                source={Color="#3c3836"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.great_wave_of_kanagawa_gruvbox},
                width=2559,
                height=1439,
                horizontal_align="Right",
                vertical_align="Top",
                horizontal_offset=2559*0.35,
                vertical_offset=-1439*0.25,
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
            },
        },

        -- Abstract maze
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.gruv_abstract_maze},
                width="Contain",
                height="Contain",
                horizontal_align="Right",
                vertical_align="Top",
                horizontal_offset="25%",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
            },
        },

        -- Astronaut with jellyfish
        {
            {
                source={File=assets.wallpapers.gruvbox_astro},
                width="Cover",
                height="Cover",
                horizontal_align="Center",
                vertical_align="Middle",
            },
        },

        -- Earth and stars minimal
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.gruvbox_minimal_space},
                width="Contain",
                height="Contain",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Center",
                vertical_align="Middle",
            },
        },

        -- Cave
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.gruvbox_wallpaper_cave},
                width="Contain",
                height="Contain",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Center",
                vertical_align="Middle",
            },
        },

        -- Diamond sunset logo thing
        {
            {
                source={Color="#191c21"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.gruv},
                width="Contain",
                height="Contain",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Center",
                vertical_align="Middle",
            },
        },
        {{
            source={File=assets.wallpapers.gruv_portal_cake},
            width="100%",
            height="Contain",
        },},

        -- Toradora - Taiga in bottom right
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.gruv_wallpaper_toradora_1},
                width=1920,
                height=1080,
                horizontal_align="Right",
                vertical_align="Bottom",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_offset=1920*0.1,
            },
        },

        -- Camping bear
        {
            {
                source={File=assets.wallpapers.gruvy_night},
                width="Cover",
                height="Cover",
                horizontal_align="Center",
                vertical_align="Middle",
            },
        },

        -- Three moons
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.moon},
                width=1920,
                height=1080,
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Right",
                vertical_align="Middle",
                horizontal_offset=1920*0.3
            },
        },

        -- Orbit image
        {
            {
                source={Color="#262626"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.orbit},
                horizontal_align="Right",
                vertical_align="Top",
                width=2295*0.3,
                height=1455*0.3,
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
            },
        },

        -- Red moon
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.red_moon},
                width=217,
                height=191,
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                horizontal_align="Right",
                vertical_align="Top",
            },
        },

        -- Rocket
        {
            {
                source={Color="#1d2021"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.rocket},
                width="Contain",
                height="Contain",
                horizontal_align="Center",
                vertical_align="Bottom",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
            },
        },

        -- Starry sky
        {
            {
                source={File=assets.wallpapers.starry_sky},
                width="Cover",
                height="Cover",
            },
        },

        -- Orange sunset
        {
            {
                source={Color="#282828"},
                width="100%",
                height="100%",
            },
            {
                source={File=assets.wallpapers.sunset},
                width=1920*1.0,
                height=1080*1.0,
                vertical_align="Bottom",
                horizontal_align="Center",
                repeat_x="NoRepeat",
                repeat_y="NoRepeat",
                vertical_offset=1080*1.0*0.3,
            },
        },
    },

    -- plain background
    plain_background = {{
        source={Color="#1d2021"},
        width="100%",
        height="100%",
        opacity=1.0
    }},

    -- Transparent background
    transparent_background = {{
        source={Color="black"},
        width="100%",
        height="100%",
        opacity=0.8,
    }}
}

return backgrounds
