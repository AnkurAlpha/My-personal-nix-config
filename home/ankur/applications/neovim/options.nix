{ ... }: {
  # All baseline editor settings are native Nixvim options.
  globals = {
    mapleader = " ";
    maplocalleader = " ";
    netrw_banner = 0;
    netrw_browse_split = 0;
    netrw_winsize = 25;
  };
  opts = {
    number = true;
    relativenumber = true;
    tabstop = 4;
    softtabstop = 4;
    shiftwidth = 4;
    expandtab = true;
    smartindent = true;
    scrolloff = 8;
    cursorcolumn = true;
    cursorline = true;
    termguicolors = true;
    undofile = true;
    backup = true;
    writebackup = true;
  };
  extraConfigLua = ''
      local state = vim.fn.stdpath("state")

      vim.fn.mkdir(state .. "/backups", "p")
      vim.fn.mkdir(state .. "/undo", "p")

      vim.opt.backupdir = { state .. "/backups//" }
  vim.opt.undodir = { state .. "/undo//" }
    vim.filetype.add({ extension = { templ = "templ" } })

    local augroup = vim.api.nvim_create_augroup("Ankur", { clear = true })
    vim.api.nvim_create_autocmd("TextYankPost", {
      group = augroup, callback = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
      end,
    })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = augroup,
      pattern = "*",
      callback = function()
        local view = vim.fn.winsaveview()
        vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
        vim.fn.winrestview(view)
      end,
    })
    vim.api.nvim_create_autocmd("LspAttach", {
      group = augroup,
      callback = function(e)
        local o = { buffer = e.buf }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, o)
        vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, o)
        vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, o)
        vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, o)
        vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, o)
        vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, o)
      end,
    })
  '';
}
