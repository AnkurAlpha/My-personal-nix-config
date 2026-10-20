{ lib, ... }:
let
  raw = lib.nixvim.mkRaw;

  # Original Garuda Eviline palette.
  colors = {
    bg = "#202328";
    fg = "#bbc2cf";
    yellow = "#ECBE7B";
    cyan = "#008080";
    darkblue = "#081633";
    green = "#98be65";
    orange = "#FF8800";
    violet = "#a9a1e1";
    magenta = "#c678dd";
    blue = "#51afef";
    red = "#ec5f67";
  };

  bufferNotEmpty = raw ''
    function()
      return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
    end
  '';

  hideInWidth = raw ''
    function()
      return vim.fn.winwidth(0) > 80
    end
  '';
in
{
  # Declarative replacement for the Garuda evil_lualine.lua.
  # plugins.nix may also set `plugins.lualine.enable = true`; that's fine.
  plugins.lualine = {
    enable = true;
    settings = {
      options = {
        icons_enabled = true;
        component_separators = "";
        section_separators = "";
        globalstatus = false; # Match the original per-window statusline.
        theme = {
          normal.c = { fg = colors.fg; bg = colors.bg; };
          inactive.c = { fg = colors.fg; bg = colors.bg; };
        };
      };

      sections = {
        lualine_a = [ ];
        lualine_b = [ ];
        lualine_y = [ ];
        lualine_z = [ ];

        lualine_c = [
          {
            __unkeyed-1 = raw ''function() return "▊" end'';
            color.fg = colors.blue;
            padding = { left = 0; right = 1; };
          }
          {
            __unkeyed-1 = raw ''function() return "" end'';
            color = raw ''
              function()
                local mode_colors = {
                  n = "#ec5f67", no = "#ec5f67",
                  i = "#98be65", ic = "#ECBE7B",
                  v = "#51afef", V = "#51afef", ["\22"] = "#51afef",
                  s = "#FF8800", S = "#FF8800", ["\19"] = "#FF8800",
                  c = "#c678dd", cv = "#ec5f67", ce = "#ec5f67",
                  R = "#a9a1e1", Rv = "#a9a1e1",
                  r = "#008080", rm = "#008080", ["r?"] = "#008080",
                  ["!"] = "#ec5f67", t = "#ec5f67",
                }
                local mode = vim.fn.mode()
                return { fg = mode_colors[mode] or mode_colors[mode:sub(1, 1)] or "#ECBE7B" }
              end
            '';
            padding = { right = 1; };
          }
          {
            __unkeyed-1 = "filesize";
            cond = bufferNotEmpty;
          }
          {
            __unkeyed-1 = "filename";
            cond = bufferNotEmpty;
            color = { fg = colors.magenta; gui = "bold"; };
          }
          "location"
          {
            __unkeyed-1 = "progress";
            color = { fg = colors.fg; gui = "bold"; };
          }
          {
            __unkeyed-1 = "diagnostics";
            sources = [ "nvim_diagnostic" ];
            symbols = { error = " "; warn = " "; info = " "; };
            # Modern lualine names these fields error/warn/info (rather than color_error/etc).
            diagnostics_color = {
              error = { fg = colors.red; };
              warn = { fg = colors.yellow; };
              info = { fg = colors.cyan; };
            };
          }
          { __unkeyed-1 = raw ''function() return "%=" end''; }
          {
            # Same visual intent as original: show the first relevant buffer LSP.
            # Modern API avoids displaying LSP clients attached to *other* files.
            __unkeyed-1 = raw ''
              function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then return "No Active Lsp" end
                return clients[1].name
              end
            '';
            icon = " LSP:";
            color = { fg = "#ffffff"; gui = "bold"; };
          }
        ];

        lualine_x = [
          {
            __unkeyed-1 = "o:encoding";
            fmt = raw ''string.upper'';
            cond = hideInWidth;
            color = { fg = colors.green; gui = "bold"; };
          }
          {
            __unkeyed-1 = "fileformat";
            fmt = raw ''string.upper'';
            icons_enabled = false;
            color = { fg = colors.green; gui = "bold"; };
          }
          {
            __unkeyed-1 = "branch";
            icon = "";
            color = { fg = colors.violet; gui = "bold"; };
          }
          {
            __unkeyed-1 = "diff";
            symbols = { added = " "; modified = "󰝤 "; removed = " "; };
            diff_color = {
              added = { fg = colors.green; };
              modified = { fg = colors.orange; };
              removed = { fg = colors.red; };
            };
            cond = hideInWidth;
          }
          {
            __unkeyed-1 = raw ''function() return "▊" end'';
            color.fg = colors.blue;
            padding.left = 1;
          }
        ];
      };

      inactive_sections = {
        lualine_a = [ ];
        lualine_b = [ ];
        lualine_c = [ ];
        lualine_x = [ ];
        lualine_y = [ ];
        lualine_z = [ ];
      };
    };
  };
}
