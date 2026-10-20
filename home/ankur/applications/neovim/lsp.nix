{ ... }: {
  # Language servers are installed by Nixvim; there is no Mason runtime fetch.
  lsp.servers = {
    lua_ls.enable = true;
    clangd.enable = true;
    pylsp.enable = true;
    bashls.enable = true;
    ts_ls.enable = true;
    cssls.enable = true;
    html.enable = true;
    jsonls.enable = true;
  };
  extraConfigLua = ''
    vim.diagnostic.config({
      float = { focusable = false, style = "minimal", border = "rounded", source = "always" },
      severity_sort = true,
    })
  '';
}
