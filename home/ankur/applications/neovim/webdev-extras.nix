{ lib, pkgs, nvimEmmetSrc, vimReactSnippetsSrc, ... }:
let
  # Declarative web development extras. Sources are locked in flake.lock.
  # These two plugins rely on other runtime components (LSP / LuaSnip),
  # so isolated vim-plugin require checks are not meaningful for them.
  nvimEmmet = pkgs.vimUtils.buildVimPlugin {
    pname = "nvim-emmet";
    version = "flake-locked";
    src = nvimEmmetSrc;
    doCheck = false;
  };

  reactSnippets = pkgs.vimUtils.buildVimPlugin {
    pname = "vim-react-snippets";
    version = "flake-locked";
    src = vimReactSnippetsSrc;
    doCheck = false;
  };
in
{
  extraPlugins = [ nvimEmmet reactSnippets ];

  # Native Nixvim-managed Emmet language server package + activation.
  lsp.servers.emmet_language_server.enable = true;

  # Preserve original Garuda shortcut for nvim-emmet's wrap feature.
  keymaps = [
    {
      mode = [ "n" "v" ];
      key = "<leader>ee";
      action = lib.nixvim.mkRaw ''require("nvim-emmet").wrap_with_abbreviation'';
      options = {
        silent = true;
        desc = "Emmet: wrap with abbreviation";
      };
    }
  ];

  # React snippet registration uses LuaSnip, which is already Nixvim-managed.
  extraConfigLuaPost = ''
    require("vim-react-snippets").setup({})
  '';
}
