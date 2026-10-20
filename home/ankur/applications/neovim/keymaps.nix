{ ... }: {
# Most keymaps from Garuda's lua/Ankur/remap.lua, represented as native Nix lists.
    keymaps = [
  { mode = "n"; key = "<leader>mm"; action = "<cmd>lua MiniMap.toggle()<CR>"; options.desc = "Toggle minimap"; }
  { mode = "n"; key = "<leader>mo"; action = "<cmd>lua MiniMap.open()<CR>"; options.desc = "Open minimap"; }
  { mode = "n"; key = "<leader>mc"; action = "<cmd>lua MiniMap.close()<CR>"; options.desc = "Close minimap"; }
  { mode = "n"; key = "<leader>mf"; action = "<cmd>lua MiniMap.toggle_focus()<CR>"; options.desc = "Focus minimap"; }
    { mode = "n"; key = "<leader>gs"; action = "<cmd>Git<CR>"; options.desc = "Open Git status"; }
    { mode = "n"; key = "<leader>mt"; action = "<cmd>RenderMarkdown toggle<CR>"; options.desc = "Toggle Markdown rendering"; }
    { mode = "n"; key = "<leader>w"; action = "<cmd>w<CR>"; }
    { mode = "n"; key = "<leader>q"; action = "<cmd>q!<CR>"; }
    { mode = "n"; key = "<leader>pv"; action = "<cmd>NvimTreeToggle<CR>"; }
    { mode = "n"; key = "<leader>pf"; action = "<cmd>Telescope find_files<CR>"; }
    { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope git_files<CR>"; }
    { mode = "n"; key = "<leader>fg"; action = "<cmd>Telescope live_grep<CR>"; }
    { mode = "n"; key = "<leader>fb"; action = "<cmd>Telescope buffers<CR>"; }
    { mode = "n"; key = "<leader>fh"; action = "<cmd>Telescope help_tags<CR>"; }
    { mode = "n"; key = "<leader>fm"; action = "<cmd>Telescope man_pages<CR>"; }
    { mode = "n"; key = "<leader>u"; action = "<cmd>UndotreeToggle<CR>"; }
    { mode = "n"; key = "<leader>nf"; action = "<cmd>Neogen func<CR>"; options.desc = "Generate function documentation"; }
    { mode = "n"; key = "<leader>nt"; action = "<cmd>Neogen type<CR>"; options.desc = "Generate type documentation"; }
    { mode = "n"; key = "<leader>tt"; action = "<cmd>Trouble diagnostics toggle<CR>"; options.desc = "Toggle Trouble diagnostics"; }
    { mode = "n"; key = "<C-t>"; action = "<cmd>ToggleTerm<CR>"; }
    { mode = "n"; key = "<C-s>"; action = "<cmd>vsplit<CR><C-w>w"; }
    { mode = "n"; key = "<C-n>"; action = "<cmd>split<CR><C-w>w"; }
    { mode = "n"; key = "<C-h>"; action = "<cmd>nohlsearch<CR>"; }
    { mode = "n"; key = "<leader>f"; action = "<cmd>lua vim.lsp.buf.format()<CR>"; }
    { mode = "n"; key = "<leader>lf"; action = "<cmd>Lspsaga finder<CR>"; }
    { mode = "n"; key = "<leader>lo"; action = "<cmd>Lspsaga outline<CR>"; }
    { mode = "n"; key = "<leader>la"; action = "<cmd>Lspsaga code_action<CR>"; }
    { mode = "n"; key = "<C-k>"; action = "<cmd>cnext<CR>zz"; }
    { mode = "n"; key = "<C-j>"; action = "<cmd>cprev<CR>zz"; }
    { mode = "n"; key = "<leader>k"; action = "<cmd>lnext<CR>zz"; }
    { mode = "n"; key = "<leader>j"; action = "<cmd>lprev<CR>zz"; }
    { mode = "n"; key = "<C-d>"; action = "<C-d>zz"; }
    { mode = "n"; key = "<C-u>"; action = "<C-u>zz"; }
    { mode = "n"; key = "n"; action = "nzzzv"; }
    { mode = "n"; key = "N"; action = "Nzzzv"; }
    { mode = "v"; key = "J"; action = ":m '>+1<CR>gv=gv"; }
    { mode = "v"; key = "K"; action = ":m '<-2<CR>gv=gv"; }
    { mode = "n"; key = "J"; action = "mzJ`z"; }
    { mode = "x"; key = "<leader>p"; action = ''"_dP''; }
    { mode = [ "n" "v" ]; key = "<leader>y"; action = ''"+y''; }
    { mode = "n"; key = "<leader>Y"; action = ''"+Y''; }
    { mode = [ "n" "v" ]; key = "<leader>d"; action = ''"_d''; }
    { mode = "i"; key = "<C-c>"; action = "<Esc>"; }
    { mode = "n"; key = "Q"; action = "<Nop>"; }
    { mode = "n"; key = "<leader>x"; action = "<cmd>!chmod +x %<CR>"; }
    { mode = "n"; key = "<leader>mr"; action = "<cmd>CellularAutomaton make_it_rain<CR>"; }
    { mode = "n"; key = "<leader>mp"; action = "<cmd>MarkdownPreviewToggle<CR>"; }
    ];
         }
