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

        trouble = {
            enable = true;
        };

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
        ts-autotag = {
            enable = true;
            callSetup = false;
        };
        render-markdown = {
            enable = true;
            settings = {
                debounce = 200;
            };
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

            settings = {
                snippet_engine = "luasnip";
            };
        };
    };

# Non-core plugins can be promoted to native Nixvim modules after testing.
# These are installed from nixpkgs, not installed/updated by lazy.nvim.
    extraPlugins = available [
        "plenary-nvim"
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
                setup("render-markdown")
                setup("cloak", {
                        enabled = true, cloak_character = "*", highlight_group = "Comment",
                        patterns = {{file_pattern={".env*", "wrangler.toml", ".dev.vars"}, cloak_pattern="=.+"}},
                        })
    setup("nvim-ts-autotag", { opts = { enable_close = true, enable_rename = true } })
        setup("fidget")
        setup("nvim-highlight-colors")
        require("nvim-ts-autotag").setup({
                opts = {
                enable_close = true,
                enable_rename = true,
                enable_close_on_slash = true,
                },

                per_filetype = {
                html = {
                enable_close = true,
                },
                },
                })
  '';
}
