-- Start in insert mode for new files
vim.api.nvim_create_autocmd("BufNewFile", {
  callback = function()
    vim.cmd("startinsert")
  end,
})
