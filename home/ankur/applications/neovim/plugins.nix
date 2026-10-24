{ lib, pkgs, ... }:
let
  # Keep optional, non-native plugins Nix-managed.
  available = names:
    lib.filter (plugin: plugin != null)
      (map (name: lib.attrByPath [ name ] null pkgs.vimPlugins) names);
in
{
  # NeoMinimap reads vim.g.neominimap before its startup plugin is loaded.
  # A true split (not a float) reserves editor width on the right.
  globals.neominimap = {
    auto_enable = true;
    layout = "split";
    split = {
      minimap_width = 12;
      direction = "right";
      fix_width = true;
      persist = true;
    };
    exclude_filetypes = [ "help" "bigfile" "NvimTree" ];
  };

  plugins = {
    # Floating mini.map retired in favor of a separate NeoMinimap split.
    lspconfig.enable = true;
    telescope.enable = true;
    treesitter = {
      enable = true;
      highlight.enable = true;
    };
    nvim-tree.enable = true;
    lualine.enable = true;
    which-key.enable = true;
    toggleterm = {
      enable = true;
      settings.direction = "float";
    };
    nvim-autopairs.enable = true;
    undotree.enable = true;
    alpha = {
      enable = true;
      theme = "dashboard";
    };
    web-devicons.enable = true;

    noice = {
      enable = true;
      settings = {
        lsp.override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
          "cmp.entry.get_documentation" = true;
        };
        presets = {
          bottom_search = false;
          command_palette = false;
          long_message_to_split = true;
          inc_rename = true;
          lsp_doc_border = true;
        };
      };
    };

    trouble.enable = true;

    indent-blankline = {
      enable = true;
      settings = {
        indent.char = "│";
        scope = {
          enabled = true;
          highlight = [
            "RainbowRed"
            "RainbowYellow"
            "RainbowBlue"
            "RainbowOrange"
            "RainbowGreen"
            "RainbowViolet"
            "RainbowCyan"
          ];
        };
      };
    };

    highlight-colors = {
      enable = true;
      settings = {
        render = "virtual";
        virtual_symbol = "■";
        virtual_symbol_position = "inline";
        enable_hex = true;
        enable_short_hex = true;
        enable_rgb = true;
        enable_hsl = true;
        enable_named_colors = true;
        enable_tailwind = true;
      };
    };

    notify = {
      enable = true;
      callSetup = false;
    };

    # Preserve custom autotag options; configured once in Lua below.
    ts-autotag = {
      enable = true;
      callSetup = false;
    };

    render-markdown = {
      enable = true;
      settings.debounce = 200;
    };

    leetcode = {
      enable = true;
      settings = {
        arg = "leetcode.nvim";
        lang = "python3";
        cn.enabled = false;
        plugins.non_standalone = false;
        logging = true;
        cache.update_interval = 604800;
        console = {
          open_on_runcode = true;
          dir = "row";
          size = {
            width = "90%";
            height = "75%";
          };
          result.size = "60%";
          testcase = {
            virt_text = true;
            size = "40%";
          };
        };
        description = {
          position = "left";
          width = "40%";
          show_stats = true;
        };
        image_support = false;
      };
    };

    lspsaga = {
      enable = true;
      settings = {
        finder.max_height = 0.6;
        outline = {
          win_width = 30;
          auto_close = true;
        };
        ui.border = "rounded";
      };
    };

    neogen = {
      enable = true;
      settings.snippet_engine = "luasnip";
    };
  };

  # NeoMinimap uses its own highlight groups.
  # Old mini.map highlights and autocmds have been removed.
  # Retain the existing Nixpkgs-installed plugins.
  extraPlugins = available [
    "plenary-nvim"
    "nui-nvim"
    "fidget-nvim"
    "vim-fugitive"
  ];

  # Only plugins needing explicit Lua configuration remain here.
  # No duplicate mini.map, render-markdown or highlight-colors setup calls.
  extraConfigLuaPost = ''
    local function setup(name, settings)
      local ok, plugin = pcall(require, name)
      if ok and type(plugin.setup) == "function" then
        pcall(plugin.setup, settings or {})
      end
    end

    setup("fidget")

    require("nvim-ts-autotag").setup({
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
      per_filetype = {
        html = { enable_close = true },
      },
    })

    require("smoothcursor").setup({
      type = "default",
      cursor = "",
      texthl = "SmoothCursor",
      fancy = {
        enable = true,
        head = { cursor = "▷", texthl = "SmoothCursor" },
        body = {
          { cursor = "󰝥" },
          { cursor = "󰝥" },
          { cursor = "●" },
          { cursor = "●" },
          { cursor = "•" },
          { cursor = "." },
          { cursor = "." },
        },
        tail = { cursor = nil, texthl = "SmoothCursor" },
      },
      autostart = true,
      always_redraw = true,
      speed = 25,
      intervals = 35,
      threshold = 3,
      timeout = 3000,
      priority = 10,
    })
  '';
}

