{ ... }: {
  colorschemes.cyberdream = {
    enable = true;
    settings = {
      transparent = true;
      italic_comments = true;
      hide_fillchars = false;
      borderless_pickers = false;
      terminal_colors = true;
      variant = "dark";
      colors = {
        bg = "#000000";
        green = "#00ff00";
        magenta = "#ff00ff";
        grey = "#ffffff";
      };
    };
  };
  # Personal highlights retained from old cyberdream config.
  extraConfigLuaPost = ''
    local overrides = {
      Comment = { fg = "#0ad510", bg = "NONE", italic = true, bold = true },
      CursorColumn = { bg = "#262e15" },
      CursorLine = { bg = "#262e15" },
      LineNrAbove = { fg = "#b00505" },
      LineNrBelow = { fg = "#b00505" },
      CurSearch = { fg = "#f40808", bg = "#ebdf0e" },
      FloatBorder = { fg = "#ff9e64" },
      WinSeparator = { fg = "#ff9e64" },
      TelescopeBorder = { fg = "#ff9e64" },
      TelescopePromptBorder = { fg = "#ff9e64" },
      TelescopeResultsBorder = { fg = "#ff9e64" },
      TelescopePreviewBorder = { fg = "#ff9e64" },
    }
    for name, hl in pairs(overrides) do vim.api.nvim_set_hl(0, name, hl) end
  '';
}
