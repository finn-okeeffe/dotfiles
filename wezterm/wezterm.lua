local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local config = wezterm.config_builder()
local background = require("backgrounds")
local utilities = require("utilities")

-- Background
local backgrounds = background.backgrounds_list
local num_wallpapers = utilities.table_length(backgrounds)
wezterm.log_info("num_wallpapers: " .. num_wallpapers)

-- Random initial background
math.randomseed(os.time())
-- local background_index = 1
local background_index = math.random(1, num_wallpapers)
local background_type = 0 -- 0: image. 1: plain colour. 2: transparent

wezterm.log_info(backgrounds[background_index])

config.background = backgrounds[background_index]
local change_background = function(window, pane, change_by)
        wezterm.log_info("Changing background...")
        local overrides = window:get_config_overrides() or {}

        -- only continue if background image is showing
        if background_type ~= 0 then
            return nil
        end

        -- increase wallpaper index
        background_index = background_index + change_by

        -- check if we reached the end of the list
        if background_index > num_wallpapers then
            background_index = 1
        elseif background_index < 1 then
            background_index = num_wallpapers
        end
        print(background_index)

        -- set background
        overrides.background = backgrounds[background_index]

        window:set_config_overrides(overrides)
end

local toggle_plain_background = function (window, pane)
    wezterm.log_info("Toggling plain background")
    local overrides = window:get_config_overrides() or {}

    if background_type == 0 then
        overrides.background = background.plain_background
        background_type = background_type + 1
    elseif background_type == 1 then
        overrides.background = background.transparent_background
        background_type = background_type + 1
    elseif background_type == 2 then
        overrides.background = backgrounds[background_index]
        background_type = 0
    end

    window:set_config_overrides(overrides)
end

wezterm.on('next-background', function(window, pane) change_background(window, pane, 1) end)
wezterm.on('previous-background', function(window, pane) change_background(window, pane, -1) end)
wezterm.on('set-plain-background', toggle_plain_background)

-- Font settings
config.font_size = 16
config.font = wezterm.font("FiraCode Nerd Font Mono")

-- Colors
config.color_scheme = 'GruvboxDarkHard'
local color_scheme = wezterm.get_builtin_color_schemes()[config.color_scheme]
wezterm.log_info(color_scheme)

-- inactive pane styling
config.inactive_pane_hsb = {
    saturation = 0.0,
    brightness = 0.4,
}

-- Window frame
config.window_frame = {
    font = wezterm.font("FiraCode Nerd Font Mono"),
    font_size = 16,
}

-- keybinds
config.leader = {
    key="j",
    mods="CTRL",
    timeout_milliseconds=500
}
config.keys = {
    {
        key="R",
        mods="LEADER",
        action=wezterm.action.ReloadConfiguration,
    },
    {
        key="b",
        mods="ALT",
        action = wezterm.action.EmitEvent("next-background"),
    },
    {
        key="b",
        mods="ALT|SHIFT",
        action = wezterm.action.EmitEvent("previous-background"),
    },
    {
        key="B",
        mods="CTRL|ALT|SHIFT",
        action = wezterm.action.EmitEvent("set-plain-background"),
    },
    {
        key="_",
        mods="ALT|SHIFT",
        action=wezterm.action.SplitPane {
            direction="Down"
        }
    },
    {
        key="+",
        mods="ALT|SHIFT",
        action=wezterm.action.SplitPane {
            direction="Right"
        }
    },
    {
        key="UpArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Up", 1
        }
    },
    {
        key="DownArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Down", 1
        }
    },
    {
        key="RightArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Right", 1
        }
    },
    {
        key="LeftArrow",
        mods="ALT|SHIFT",
        action=wezterm.action.AdjustPaneSize {
            "Left", 1
        }
    },
    {
        key="LeftArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Left",
    },
    {
        key="RightArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Right",
    },
    {
        key="UpArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Up",
    },
    {
        key="DownArrow",
        mods="ALT",
        action=wezterm.action.ActivatePaneDirection "Down",
    },
    {
        key="w",
        mods="CTRL",
        action = wezterm.action.CloseCurrentPane { confirm = true},
    },
    {
        key="UpArrow",
        mods="CTRL|SHIFT",
        action=wezterm.action.ScrollByLine(-1),
    },
    {
        key="DownArrow",
        mods="CTRL|SHIFT",
        action=wezterm.action.ScrollByLine(1),
    },
    {
        key="F11",
        action=wezterm.action.ToggleFullScreen,
    },
    {
        key = "w",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
          end),
    },
    {
        key = "W",
        mods = "ALT",
        action = resurrect.window_state.save_window_action(),
    },
    {
        key = "T",
        mods = "ALT",
        action = resurrect.tab_state.save_tab_action(),
    },
    {
        key = "s",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.window_state.save_window_action()
        end),
    },
    { -- loading states with fuzzy find
        key = "r",
        mods = "ALT",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$") -- match after '/'
                id = string.match(id, "(.+)%..+$") -- remove file extention
                local opts = {
                    relative = true,
                    restore_text = true,
                    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end),
    },
}

-- Disable top bar
config.window_decorations = "RESIZE"

-- Tab bar customisation
wezterm.on("update-right-status", function(window, pane)
    local time = wezterm.strftime("%H:%M")
    window:set_right_status(
        wezterm.format({
            {Text=time .. "   "}
        })
    )
end)


-- =========================
-- Windows specific settings
-- =========================

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    -- Launch in powershell
    config.default_prog = {'powershell.exe'}
end



return config
