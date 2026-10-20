{ pkgs, ... }:
{
  # OPTIONAL: import only after dashboard, statusline, and snippets work.
  # windows.nvim is older; it may need adjustment on modern Neovim.
  extraPlugins = with pkgs.vimPlugins; [
    (windows-nvim.overrideAttrs (old: {
      dependencies = (old.dependencies or []) ++ [ middleclass animation-nvim ];
    }))
    middleclass
    animation-nvim
  ];
  opts = {
    winwidth = 10;
    winminwidth = 10;
    equalalways = false;
  };
  extraConfigLuaPost = ''require("windows").setup()'';
  keymaps = [
    { mode = "n"; key = "<C-w>z"; action = "<cmd>WindowsMaximize<CR>"; options.desc = "Maximize window"; }
    { mode = "n"; key = "<C-w>_"; action = "<cmd>WindowsMaximizeVertically<CR>"; options.desc = "Maximize vertically"; }
    { mode = "n"; key = "<C-w>|"; action = "<cmd>WindowsMaximizeHorizontally<CR>"; options.desc = "Maximize horizontally"; }
    { mode = "n"; key = "<C-w>="; action = "<cmd>WindowsEqualize<CR>"; options.desc = "Equalize windows"; }
  ];
}
