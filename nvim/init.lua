-- options --
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.showmode = false
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.signcolumn = "yes"
vim.opt.hlsearch = true
vim.o.termguicolors = true

-- globals --
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- plugins --
-- old old theme
-- "https://github.com/WTFox/jellybeans.nvim",
-- old theme
-- "https://github.com/oskarnurm/koda.nvim"
vim.pack.add({
	"https://github.com/tpope/vim-sleuth",
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/nvim-mini/mini.pairs",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-lualine/lualine.nvim",
	"https://github.com/stevearc/oil.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/WTFox/luna.nvim",
	"https://github.com/rafamadriz/friendly-snippets",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	{ src = "https://github.com/saghen/blink.cmp", version = 'v1.10.1' },
	'https://github.com/nvim-mini/mini.icons',
	'https://github.com/MeanderingProgrammer/render-markdown.nvim',
})

-- plugins: setup --
require("gitsigns").setup({
	signs = {
		add = { text = "+" },
		change = { text = "~" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
	},
})
require("mini.pairs").setup({})
-- search hidden files (e.g. .github) but skip .git
local vimgrep_arguments = { unpack(require("telescope.config").values.vimgrep_arguments) }
table.insert(vimgrep_arguments, "--hidden")
table.insert(vimgrep_arguments, "--glob")
table.insert(vimgrep_arguments, "!**/.git/*")
require("telescope").setup({
	defaults = {
		file_ignore_patterns = {
			"%.patch$",
		},
		vimgrep_arguments = vimgrep_arguments,
	},
	pickers = {
		find_files = {
			find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
		},
	},
})
require("lualine").setup({ options = { theme = "auto" } })
require("oil").setup({
	keymaps = {
		["g."] = "actions.toggle_hidden",
	},
	view_options = {
		show_hidden = false,
	},
})
-- grn (to rename current variable)
-- grr (get all references in quick fix list)
-- crtl + S in insert mode tells you signature of func
require("blink.cmp").setup({
	keymap = { preset = 'default' },
	completion = { documentation = { auto_show = false } },
	sources = { default = {'lsp', 'path', 'snippets', 'buffer'} },
	fuzzy = { implementation = 'prefer_rust_with_warning'}
})
vim.lsp.config("*", { capabilities = require('blink.cmp').get_lsp_capabilities() })
vim.lsp.enable({"gopls", "rust_analyzer", "clangd", "pyright", "bash-language-server"})
local languages = { 'rust', 'c', 'python', 'go', 'lua', 'bash' }
require("nvim-treesitter").install(languages)

vim.cmd("colorscheme luna")

-- keymaps --
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>") -- clear search with Esc
vim.keymap.set("n", "<C-h>", "<C-w><C-h>") -- Move focus to left window
vim.keymap.set("n", "<C-l>", "<C-w><C-l>") -- Move focus to right window
vim.keymap.set("n", "<C-j>", "<C-w><C-j>") -- Move focus to lower window
vim.keymap.set("n", "<C-k>", "<C-w><C-k>") -- Move focus to upper window
vim.keymap.set("n", "<leader>w", ":write<CR>") -- write the current buffer
vim.keymap.set("n", "<leader>u", ":source<CR> :update<CR>") -- source the current file
vim.keymap.set("n", "<leader>q", ":quit<CR>") -- quit
vim.keymap.set("n", "<leader>k", ":bdelete<CR>") -- kill buffer
-- keymaps: plugins --
vim.keymap.set("n", "<leader>e", ":Oil<CR>") -- Oil
vim.keymap.set("n", "<leader>sf", require("telescope.builtin").find_files)
vim.keymap.set("n", "<leader>sg", require("telescope.builtin").live_grep)
vim.keymap.set("n", "<leader>sw", require("telescope.builtin").grep_string) -- search word
vim.keymap.set("n", "<leader>sm", function()
	require("telescope.builtin").man_pages({ sections = { "ALL" } })
end) -- search man pages
vim.keymap.set("n", "<leader>sr", require("telescope.builtin").lsp_references) -- search references
vim.keymap.set("n", "K", vim.lsp.buf.hover)
vim.keymap.set("n", "gd", require("telescope.builtin").lsp_definitions)
vim.keymap.set("n", "gi", require("telescope.builtin").lsp_implementations)
vim.keymap.set("n", "<leader>E", vim.diagnostic.setloclist) -- show errors
-- in case of switching between buffers be in normal mode instead
vim.keymap.set("n", "<leader><leader>", function() require("telescope.builtin").buffers({ initial_mode = "normal" }) end)

-- misc
-- highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = languages,
	callback = function() vim.treesitter.start() end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "man",
  callback = function()
    vim.cmd.wincmd("H") -- far left
  end,
})
