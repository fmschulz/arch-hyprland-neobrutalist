vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.clipboard = "unnamedplus"
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.mouse = "a"
opt.completeopt = { "menu", "menuone", "noselect" }

local palette = {
  bg = "#FFF8E7",
  fg = "#000000",
  yellow = "#FFBE0B",
  orange = "#FB5607",
  pink = "#FF006E",
  purple = "#8338EC",
  mint = "#06FFA5",
  blue = "#3A86FF",
  gray = "#808080",
  white = "#FFFFFF",
}

local hl = vim.api.nvim_set_hl

hl(0, "Normal", { fg = palette.fg, bg = palette.bg })
hl(0, "NormalFloat", { fg = palette.fg, bg = palette.white })
hl(0, "FloatBorder", { fg = palette.fg, bg = palette.white, bold = true })
hl(0, "CursorLine", { bg = "#FFE6A7" })
hl(0, "CursorLineNr", { fg = palette.orange, bold = true })
hl(0, "LineNr", { fg = palette.gray })
hl(0, "Comment", { fg = palette.blue, italic = true })
hl(0, "String", { fg = palette.orange })
hl(0, "Identifier", { fg = palette.purple })
hl(0, "Function", { fg = palette.pink, bold = true })
hl(0, "Keyword", { fg = palette.blue, bold = true })
hl(0, "Type", { fg = palette.purple, bold = true })
hl(0, "Search", { fg = palette.fg, bg = palette.yellow, bold = true })
hl(0, "Visual", { fg = palette.fg, bg = "#FFD166" })
hl(0, "StatusLine", { fg = palette.fg, bg = palette.yellow, bold = true })
hl(0, "StatusLineNC", { fg = palette.fg, bg = "#E5E5E5" })
hl(0, "VertSplit", { fg = palette.fg, bg = palette.bg })
hl(0, "Pmenu", { fg = palette.fg, bg = palette.white })
hl(0, "PmenuSel", { fg = palette.fg, bg = palette.mint, bold = true })
hl(0, "DiagnosticError", { fg = palette.pink, bold = true })
hl(0, "DiagnosticWarn", { fg = palette.orange, bold = true })
hl(0, "DiagnosticInfo", { fg = palette.blue, bold = true })
hl(0, "DiagnosticHint", { fg = palette.purple, bold = true })

vim.cmd("syntax on")
vim.cmd("filetype plugin indent on")

vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Write buffer" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close buffer" })
vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
vim.keymap.set("n", "<leader>e", "<cmd>Explore<cr>", { desc = "Open netrw" })
vim.keymap.set("n", "<leader>y", "<cmd>terminal yazi<cr>", { desc = "Open Yazi" })
vim.keymap.set("n", "<leader>r", "<cmd>terminal ~/.config/scripts/radio.sh<cr>", { desc = "Open radio selector" })

vim.o.statusline = table.concat({
  " ",
  "%f",
  " %m",
  "%=",
  " %y ",
  " %l:%c ",
})
