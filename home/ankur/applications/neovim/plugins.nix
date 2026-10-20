{ lib, pkgs, ... }:
let
  # Optional plugins are Nix-managed. Missing packages are skipped rather than
  # preventing the editor's first reproducible build.
  available = names: lib.filter (x: x != null)
    (map (name: lib.attrByPath [ name ] null pkgs.vimPlugins) names);
in {
  plugins = {
    lspconfig.enable = true;  # Add this
    telescope.enable = true;
    treesitter = { enable = true; highlight.enable = true; };
    nvim-tree.enable = true;
    lualine.enable = true;
    which-key.enable = true;
    toggleterm = { enable = true; settings.direction = "float"; };
    nvim-autopairs.enable = true;
    undotree.enable = true;
    alpha = { enable = true; theme = "dashboard"; };
    web-devicons.enable = true;

  };

  # Non-core plugins can be promoted to native Nixvim modules after testing.
  # These are installed from nixpkgs, not installed/updated by lazy.nvim.
  extraPlugins = available [
      "plenary-nvim"
          "nvim-notify"
          "nui-nvim"
          "fidget-nvim"
          "vim-fugitive"
  ];
  # extraPlugins = available [
  #   "plenary-nvim" "nvim-notify" "nui-nvim" "fidget-nvim" "vim-fugitive"
  #   "trouble-nvim" "render-markdown-nvim" "cloak-nvim"
  #   "nvim-ts-autotag" "leetcode-nvim" "lspsaga-nvim"
  #   "nvim-highlight-colors" "indent-blankline-nvim"
  #   "cellular-automaton-nvim" "codewindow-nvim" "smoothcursor-nvim"
  #   "nvim-emmet" "neogen" "windows-nvim"
  #   "middleclass" "animation-nvim" "vim-react-snippets"
  #   "markdown-preview-nvim"
  # ];

  extraConfigLuaPost = ''
    -- Configure remaining Nix-installed plugins only when present.
    local function setup(name, settings)
      local ok, plugin = pcall(require, name)
      if ok and type(plugin.setup) == "function" then
        pcall(plugin.setup, settings or {})
      end
    end
    setup("notify", { background_colour = "#000000" })
    setup("trouble", { icons = false })
    setup("render-markdown")
    setup("cloak", {
      enabled = true, cloak_character = "*", highlight_group = "Comment",
      patterns = {{file_pattern={".env*", "wrangler.toml", ".dev.vars"}, cloak_pattern="=.+"}},
    })
    setup("nvim-ts-autotag", { opts = { enable_close = true, enable_rename = true } })
    setup("lspsaga", { ui = { border = "rounded" } })
    setup("fidget")
    setup("noice", {})
    setup("neogen", {})
    setup("nvim-highlight-colors")
  '';
}
