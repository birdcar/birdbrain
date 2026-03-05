-- Save and quit with Cmd+S / Ctrl+S (back to Claude Code)
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Cmd>wq<CR>", { desc = "Save and quit" })

-- Double-Escape saves and quits (fast exit back to Claude)
vim.keymap.set("n", "<Esc><Esc>", "<Cmd>wq<CR>", { desc = "Save and quit" })
