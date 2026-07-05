-- servers (configs come from nvim-lspconfig, client is built-in)
vim.lsp.enable('clangd')
vim.lsp.enable('lua_ls')
vim.lsp.enable('nixd')
vim.lsp.enable('bashls')

vim.diagnostic.config {
    virtual_text = true,
}

-- menu opens automatically with the first item selected; noinsert
-- keeps it from writing into the buffer until accepted with <C-y>
vim.opt.completeopt = { 'menuone', 'noinsert', 'popup' }
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
	local client = vim.lsp.get_client_by_id(args.data.client_id)
	if client and client:supports_method('textDocument/completion') then
	    vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
	end
    end,
})
