{ lib, ... }:
{
  # Override the stock dashboard layout configured in plugins.nix.
  # The native Alpha module still owns installation and its setup lifecycle.
  plugins.alpha = {
    enable = true;
    theme = lib.mkForce null;
    settings = {
      opts = { margin = 5; };
      layout = [
        { type = "padding"; val = 2; }
        {
          type = "text";
          val = [
            "                                                     "
            "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ "
            "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ "
            "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ "
            "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ "
            "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ "
            "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ "

          ];
          opts = { position = "center"; hl = "Type"; };
        }
        { type = "padding"; val = 2; }
        {
          type = "group";
          opts = { spacing = 1; };
          val = [
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("n", "  > New file", ":ene <BAR> startinsert <CR>")'')
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("o", "🗁  > Open folder", ":NvimTreeFocus <CR>")'')
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("l", "✰  > LeetCode", ":Leet <CR>")'')
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("f", "🖳  > Find file", ":Telescope find_files<CR>")'')
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("r", "  > Recent", ":Telescope oldfiles<CR>")'')
            (lib.nixvim.mkRaw ''require("alpha.themes.dashboard").button("q", "⎋  > Quit NVIM", ":qa<CR>")'')
          ];
        }
        { type = "padding"; val = 2; }
        {
          type = "text";
          val = "Code · Build · Create";
          opts = { position = "center"; hl = "Comment"; };
        }
      ];
    };
  };

  # Avoid folding the dashboard if options change in other modules.
  autoCmd = [
    { event = [ "FileType" ]; pattern = "alpha"; command = "setlocal nofoldenable"; }
  ];
}
