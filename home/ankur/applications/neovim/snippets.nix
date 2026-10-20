{ lib, pkgs, ... }:
{
  # LuaSnip is already enabled by completion.nix; these merge into that module.
  plugins.luasnip = {
    enable = true;
    fromVscode = [ {} ]; # lazy-load friendly-snippets on demand
  };
  extraPlugins = [ pkgs.vimPlugins.friendly-snippets ];

  # Restore Garuda's exact LuaSnip keystrokes.
  keymaps = [
    {
      mode = "i";
      key = "<C-s>e";
      action = lib.nixvim.mkRaw ''function() require("luasnip").expand() end'';
      options = { silent = true; desc = "LuaSnip: expand"; };
    }
    {
      mode = [ "i" "s" ];
      key = "<C-s>;";
      action = lib.nixvim.mkRaw ''function() require("luasnip").jump(1) end'';
      options = { silent = true; desc = "LuaSnip: next field"; };
    }
    {
      mode = [ "i" "s" ];
      key = "<C-s>,";
      action = lib.nixvim.mkRaw ''function() require("luasnip").jump(-1) end'';
      options = { silent = true; desc = "LuaSnip: previous field"; };
    }
    {
      mode = [ "i" "s" ];
      key = "<C-e>";
      action = lib.nixvim.mkRaw ''function()
        local ls = require("luasnip")
        if ls.choice_active() then ls.change_choice(1) end
      end'';
      options = { silent = true; desc = "LuaSnip: next choice"; };
    }
  ];
}
