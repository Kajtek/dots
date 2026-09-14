-- Minimal Hyprland session that hosts regreet on the login screen; exits once regreet does.
hl.on("hyprland.start", function()
    hl.exec_cmd("regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
