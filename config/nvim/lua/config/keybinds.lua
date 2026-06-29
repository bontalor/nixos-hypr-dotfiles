-- leader
vim.g.mapleader = " "
-- make file executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })
-- cd alias for Ex
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)
-- make ctrl+c act like esc
vim.keymap.set("i", "<C-c>", "<Esc>")
