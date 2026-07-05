-- lualine
require('lualine').setup {
    options = {
	-- remove separators
	section_separators = '',
	component_separators = '',
	theme = require("config.lortheme.lualine"),
    }
}
-- telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
-- treesitter
require("tree-sitter-manager").setup { 
    auto_install = true,
}
-- highlight-colors
require('nvim-highlight-colors').setup()
require('config.highlight-colors-cterm')
