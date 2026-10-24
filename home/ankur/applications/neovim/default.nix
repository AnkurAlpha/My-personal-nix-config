{ lib, pkgs, osConfig, fimloomSrc, config, smoothcursorSrc, neominimapSrc, nvimEmmetSrc, vimReactSnippetsSrc, ... }:
let
active = osConfig.my.apps.development.enable && osConfig.my.apps.development.neovim.enable;
fim = config.my.neovim.fimloom;
vimPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "fimloom.nvim";
    version = "flake-locked";
    src = fimloomSrc;
};
smoothcursorPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "SmoothCursor.nvim";
    version = "garuda-pinned";
    src = smoothcursorSrc;
};
neoMinimapPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "neominimap.nvim";
    version = "3.16.0";
    src = neominimapSrc;
};
in
{
    options.my.neovim.fimloom = {
        enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install AnkurAlpha/fimloom.nvim (starts disabled until :FIMLoom start).";
        };
        autoStartServer = lib.mkEnableOption "automatic llama.cpp server startup from FIMLoom";
        modelPath = lib.mkOption {
            type = lib.types.str;
            default = "~/.local/share/fimloom/models/qwen2.5-coder-7b-q4_k_m.gguf";
            description = "GGUF path on this computer; model weights are deliberately not imported into the Nix store.";
        };
        endpoint = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:9012";
            description = "URL of the local llama.cpp server.";
        };
    };

    config = lib.mkIf active {
        programs.nixvim = {
            _module.args = { inherit nvimEmmetSrc vimReactSnippetsSrc; };
            enable = true;
            defaultEditor = true;
            viAlias = true;
            vimAlias = true;

            imports = [ ./options.nix ./keymaps.nix ./theme.nix ./plugins.nix ./lsp.nix ./completion.nix ./dashboard.nix ./statusline.nix ./snippets.nix ./webdev-extras.nix ];

            extraPackages = with pkgs; [ ripgrep fd git curl ]
                ++ lib.optionals (fim.enable && fim.autoStartServer) [ llama-cpp ];

            extraPlugins =
                (lib.optionals fim.enable [ vimPlugin ])
                ++ [ smoothcursorPlugin neoMinimapPlugin ];
# FIMLoom bindings also disappear when its plugin switch is disabled.
            keymaps = lib.optionals fim.enable [
            { mode = "n"; key = "<leader>i"; action = "<cmd>FIMLoom start<CR>"; }
            { mode = "n"; key = "<leader>I"; action = "<cmd>FIMLoom stop<CR>"; }
            ];
            extraConfigLuaPost = lib.optionalString fim.enable ''
                -- FIMLoom is fetched via flake.lock; never git-cloned at Neovim startup.
                -- Retain the Garuda preference: disabled until explicitly started.
                require("fimloom").setup({
                        enabled = false,
                        provider = "llamacpp",
                        endpoint = ${builtins.toJSON fim.endpoint},
                        model = vim.fn.expand(${builtins.toJSON fim.modelPath}),
                        transport = { request_timeout_ms = 120000 },
                        completion = {
                        auto_trigger = true,
                        debounce_ms = 250,
                        trim_trailing_blank_lines = true,
                        preserve_matching_prefix = true,
                        generation = { max_tokens = 128, temperature = 0.0 },
                        },
                        ui = { suggestion = { fg = "#808080", ctermfg = 244, italic = false } },
                        server = {
                        auto_start = ${if fim.autoStartServer then "true" else "false"},
                        auto_stop = false,
                        startup_timeout_ms = 180000,
                        ${lib.optionalString fim.autoStartServer ''
                        command = function(c)
                        return {
                            "llama-server", "--model", c.model,
                            "--host", "127.0.0.1", "--port", "9012",
                            "--ctx-size", "4096", "--n-gpu-layers", "999",
                            "--no-warmup", "--sleep-idle-seconds", "300"
                        }
                        end,
                            ''}
                        },
                })
            '';
        };
    };
}
