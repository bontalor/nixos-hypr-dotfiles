local M = {}

-- terminal palette indexes, used when no pywal cache is available
local cterm_palette = {
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

M.colors = cterm_palette

-- pywal writes the hex values it pushed to the terminal here; using them as
-- gui colors keeps the theme on the terminal's 16 colors with termguicolors on
local function read_wal_palette()
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.cache/wal/colors.json"))
  if not ok then return nil end
  local ok_json, wal = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_json or type(wal) ~= "table" or type(wal.colors) ~= "table" then return nil end
  local palette = {}
  for name, index in pairs(cterm_palette) do
    local hex = wal.colors["color" .. index]
    if type(hex) ~= "string" then return nil end
    palette[name] = hex
  end
  return palette
end

function M.load()
  local wal = read_wal_palette()
  local gui = wal ~= nil

  vim.cmd("highlight clear")
  vim.g.colors_name = "lortheme"
  vim.o.termguicolors = gui
  M.colors = wal or cterm_palette
  local c = M.colors

  local function hl(group, spec)
    local attrs = { bold = spec.bold, reverse = spec.reverse }
    if spec.fg then attrs[gui and "fg" or "ctermfg"] = c[spec.fg] end
    if spec.bg then attrs[gui and "bg" or "ctermbg"] = spec.bg == "none" and "none" or c[spec.bg] end
    vim.api.nvim_set_hl(0, group, attrs)
  end

  hl("Normal", { fg = "bright_white", bg = "none" })
  hl("NormalFloat", { fg = "bright_white", bg = "black" })
  hl("FloatBorder", { fg = "bright_black", bg = "black" })

  hl("Comment", { fg = "bright_black" })
  hl("Keyword", { fg = "red" })
  hl("String", { fg = "green" })
  hl("Function", { fg = "blue" })
  hl("Identifier", { fg = "magenta" })
  hl("Type", { fg = "cyan" })

  hl("LineNr", { fg = "bright_white", bg = "black" })
  hl("CursorLineNr", { fg = "magenta", bg = "black" })
  hl("CursorLine", { bg = "black" })

  hl("Visual", { reverse = true })

  hl("Pmenu", { fg = "bright_white", bg = "black" })
  hl("PmenuSel", { fg = "black", bg = "blue" })
  hl("PmenuSbar", { bg = "black" })
  hl("PmenuThumb", { bg = "bright_black" })
  hl("PmenuMatch", { fg = "cyan", bold = true })
  hl("PmenuMatchSel", { fg = "black", bg = "blue", bold = true })

  -- match lualine's section c so the statusline doesn't flash the
  -- default reverse-video (white) highlight before lualine loads
  hl("StatusLine", { fg = "white", bg = "black" })
  hl("StatusLineNC", { fg = "white", bg = "black" })
end

-- reload when pywal regenerates the palette (wallpaper change)
local watcher, debounce
function M.watch(on_reload)
  if watcher then return end
  local dir = vim.fn.expand("~/.cache/wal")
  if vim.fn.isdirectory(dir) == 0 then return end
  watcher = assert(vim.uv.new_fs_event())
  debounce = assert(vim.uv.new_timer())
  watcher:start(dir, {}, function(_, filename)
    if filename and filename ~= "colors.json" then return end
    debounce:start(100, 0, vim.schedule_wrap(function()
      M.load()
      if on_reload then on_reload() end
    end))
  end)
end

return M
