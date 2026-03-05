-- Always start in insert mode — Birdbrain users aren't vim users
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.cmd("startinsert")
  end,
})
