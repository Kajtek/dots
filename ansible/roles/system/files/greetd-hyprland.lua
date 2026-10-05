-- Minimal Hyprland session that hosts regreet on the login screen; exits once regreet does.
-- Same cursor as the desktop session (hypr/.config/hypr/hyprland.lua).
hl.env("XCURSOR_THEME", "Breeze_Light")
hl.env("XCURSOR_SIZE", "24")

-- regreet draws on one output only, so every other monitor mirrors the laptop panel and the login
-- screen shows everywhere. The panel is 1920x1080 and a 4K monitor mirrors it at exactly 2x, so
-- nothing stretches. On a machine without eDP-1 the mirror has no source and outputs stay separate.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = "auto", mirror = "eDP-1" })
hl.on("hyprland.start", function()
    hl.exec_cmd("regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
