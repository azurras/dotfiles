vim.opt.termguicolors = false
vim.opt.background = "dark"
vim.opt.number = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wrap = true
vim.opt.breakindent = true
vim.opt.tabstop = 2         -- number of spaces a tab counts for
vim.opt.shiftwidth = 2      -- number of spaces to use for each step of (auto)indent
vim.opt.softtabstop = 2     -- number of spaces a <Tab> feels like
vim.opt.expandtab = true    -- tabs are converted to spaces
vim.g.mapleader = " "       -- Make sure to set `mapleader` before lazy so your mappings are correct

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

vim.opt.completeopt = { "menu", "menuone", "noselect" }

require("lazy").setup({
  {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup()
    end,
  }, 
  {
    "folke/neoconf.nvim",
    cmd = "Neoconf",
  },
  "folke/neodev.nvim",
--  {
--    "folke/tokyonight.nvim",
--    config = function()
--      vim.cmd.colorscheme("tokyonight")
--    end,
--  },
  {
    "sainnhe/gruvbox-material",
    priority = 1000, -- ensure it's loaded first
    config = function()
      vim.g.gruvbox_material_background = "medium" -- or "soft","medium" "hard"
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_disable_italic_comment = 1
      vim.cmd.colorscheme("gruvbox-material")
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        filesystem = {
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = true,
          },
        },
        window = {
          width = 32,
        },
      })
      vim.keymap.set("n", "<C-n>", ":Neotree toggle<CR>", { silent = true })
    end,
	},
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },
})

-- Machine-local overrides (not committed). Example: ~/.config/nvim/lua/local.lua
do
  local local_lua = vim.fn.stdpath("config") .. "/lua/local.lua"
  if vim.loop.fs_stat(local_lua) then
    pcall(dofile, local_lua)
  end
end
