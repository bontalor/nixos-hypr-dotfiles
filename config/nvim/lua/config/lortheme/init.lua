local M = {}

M.colors = {
  black         = 0,
  red           = 1,
  green         = 2,
  yellow        = 3,
  blue          = 4,
  magenta       = 5,
  cyan          = 6,
  white         = 7,
  bright_black  = 8,
  bright_red    = 9,
  bright_green  = 10,
  bright_yellow = 11,
  bright_blue   = 12,
  bright_magenta= 13,
  bright_cyan   = 14,
  bright_white  = 15,
}

function M.load()
  vim.cmd("highlight clear")
  vim.g.colors_name = "lortheme"

  vim.opt.termguicolors = false

  local hl = vim.api.nvim_set_hl

  hl(0, "Normal", { ctermfg = 15, ctermbg = "none" })
  hl(0, "NormalFloat", { ctermfg = 15, ctermbg = 0 })
  hl(0, "FloatBorder", { ctermfg = 8, ctermbg = 0 })

  hl(0, "Comment", { ctermfg = 8 })
  hl(0, "Keyword", { ctermfg = 1 })
  hl(0, "String", { ctermfg = 2 })
  hl(0, "Function", { ctermfg = 4 })
  hl(0, "Identifier", { ctermfg = 5 })
  hl(0, "Type", { ctermfg = 6 })

  hl(0, "LineNr", { ctermfg = 15, ctermbg = 0 })
  hl(0, "CursorLineNr", { ctermfg = 5, ctermbg = 0 })
  hl(0, "CursorLine", { ctermbg = 0 })

  hl(0, "Visual", { reverse = true })

  hl(0, "Pmenu", { ctermfg = 15, ctermbg = 0 })
  hl(0, "PmenuSel", { ctermfg = 0, ctermbg = 4 })
  hl(0, "PmenuSbar", { ctermbg = 0 })
  hl(0, "PmenuThumb", { ctermbg = 8 })
  hl(0, "PmenuMatch", { ctermfg = 6, bold = true })
  hl(0, "PmenuMatchSel", { ctermfg = 0, ctermbg = 4, bold = true })

  -- match lualine's section c so the statusline doesn't flash the
  -- default reverse-video (white) highlight before lualine loads
  hl(0, "StatusLine", { ctermfg = 7, ctermbg = 0 })
  hl(0, "StatusLineNC", { ctermfg = 7, ctermbg = 0 })
end

return M
