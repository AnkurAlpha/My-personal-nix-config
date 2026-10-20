{ lib, ... }: {
  plugins.luasnip.enable = true;
  plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings = {
      snippet.expand = lib.nixvim.mkRaw ''function(args) require("luasnip").lsp_expand(args.body) end'';
      mapping = {
        "<C-p>" = "cmp.mapping.select_prev_item()";
        "<C-n>" = "cmp.mapping.select_next_item()";
        "<C-y>" = "cmp.mapping.confirm({ select = true })";
        "<C-Space>" = "cmp.mapping.complete()";
      };
      sources = [
        { name = "nvim_lsp"; }
        { name = "luasnip"; }
        { name = "path"; }
        { name = "buffer"; }
      ];
    };
  };
}
