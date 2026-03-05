-- Save with Ctrl+S
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Cmd>w<CR>", { desc = "Save" })

-- Save and quit with Ctrl+Q (back to Claude Code)
vim.keymap.set({ "n", "i", "v" }, "<C-q>", "<Cmd>wq<CR>", { desc = "Save and quit" })

-- Double-Escape saves and quits (fast exit back to Claude)
vim.keymap.set("n", "<Esc><Esc>", "<Cmd>wq<CR>", { desc = "Save and quit" })
