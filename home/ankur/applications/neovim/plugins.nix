{ lib, pkgs, ... }:
let
  # Keep optional, non-native plugins Nix-managed.
  available = names:
    lib.filter (plugin: plugin != null)
      (map (name: lib.attrByPath [ name ] null pkgs.vimPlugins) names);
in
{
  plugins = {
    # Mini.map: Nixvim owns setup, size, Braille encoding and integrations.
    mini-map = {
      enable = true;
      settings = {
        integrations = [
          (lib.nixvim.mkRaw ''require("mini.map").gen_integration.builtin_search()'')
          (lib.nixvim.mkRaw ''
            require("mini.map").gen_integration.diagnostic({
              error = "DiagnosticError",
              warn = "DiagnosticWarn",
              info = "DiagnosticInfo",
              hint = "DiagnosticHint",
            })
          '')
        ];

        symbols = {
          encode = lib.nixvim.mkRaw ''require("mini.map").gen_encode_symbols.dot("4x2")'';
          scroll_line = "▏";
          scroll_view = "┃";
        };

        window = {
          side = "right";
          width = 12;
          winblend = 0;
          focusable = false;
          show_integration_count = false;
        };
      };
    };

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

  # Nixvim highlight declarations, rather than runtime imperative Lua.
  highlight = {
    MiniMapNormal = {
      fg = "#f6c177";
      bg = "NONE";
    };
    MiniMapSymbolLine = {
      fg = "#ffb86c";
      bold = true;
    };
    MiniMapSymbolView = {
      fg = "#ffd166";
      bold = true;
    };
    MiniMapSymbolCount = {
      fg = "#ff9e64";
      bold = true;
    };
  };

  # Open the minimap on ordinary named files, not dashboard/special buffers.
  autoCmd = [
    {
      event = [ "VimEnter" "BufEnter" ];
      desc = "Open mini.map automatically for normal files";
      callback = lib.nixvim.mkRaw ''
        function(event)
          local buf = event.buf
          if not buf or buf == 0 then
            buf = vim.api.nvim_get_current_buf()
          end
          if not vim.api.nvim_buf_is_valid(buf) then return end
          if vim.bo[buf].buftype ~= "" then return end
          if vim.api.nvim_buf_get_name(buf) == "" then return end

          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(buf)
                and vim.api.nvim_get_current_buf() == buf
                and vim.bo[buf].buftype == "" then
              require("mini.map").open()
            end
          end)
        end
      '';
    }
  ];

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

    -- Optional: this only does something if cloak.nvim is installed elsewhere.
    setup("cloak", {
      enabled = true,
      cloak_character = "*",
      highlight_group = "Comment",
      patterns = {
        {
          file_pattern = { ".env*", "wrangler.toml", ".dev.vars" },
          cloak_pattern = "=.+",
        },
      },
    })

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

