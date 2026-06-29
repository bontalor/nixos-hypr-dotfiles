local M = require("config.lortheme")

local c = M.colors

return {
  normal = {
    a = { fg = c.black, bg = c.blue },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },

  insert = {
    a = { fg = c.black, bg = c.green },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },

  visual = {
    a = { fg = c.black, bg = c.magenta },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },

  replace = {
    a = { fg = c.black, bg = c.red },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },

  command = {
    a = { fg = c.black, bg = c.yellow },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },

  inactive = {
    a = { fg = c.white, bg = c.black },
    b = { fg = c.white, bg = c.bright_black },
    c = { fg = c.white, bg = c.black },
  },
}
