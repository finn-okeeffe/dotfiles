local wezterm = require("wezterm")
local config = wezterm.config_builder()

wezterm.on('toggle-background', function(window, pane)
    local overrides = window.get_config_overrides() or {}
    if not overrides.window_backgroud_image then
        overrides.window_backgroud_image = "/home/finnokeeffe/git/dotfiles/wezterm/assets/gruvbox-wallpaper-cave.png"
    else
        overrides.window_backgroud_image = nil
    end
    window:set_config_overrides(overrides)
end)

-- Font settings
config.font_size = 16
config.font = wezterm.font("FiraCode Nerd Font Mono")

-- Colors
config.color_scheme = 'GruvboxDarkHard'

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
        mods="CTRL",
        action = wezterm.action.EmitEvent 'toggle-background',
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
}

-- Remove top bars
config.window_decorations = "RESIZE" -- disable title bar
config.hide_tab_bar_if_only_one_tab = true


-- =========================
-- Windows specific settings
-- =========================

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    -- Launch in powershell
    config.default_prog = {'powershell.exe'}
end



return config
