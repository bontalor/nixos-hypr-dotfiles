-- nvim-highlight-colors only sets gui colors, which are ignored with
-- termguicolors off (lortheme is cterm-based). Its highlights use
-- default = true, so pre-defining the same group here with cterm
-- attributes added wins over the plugin's gui-only definition.
local hc_utils = require('nvim-highlight-colors.utils')
local hc_colors = require('nvim-highlight-colors.color.utils')

-- nearest xterm-256 color: 6x6x6 cube (16-231) or grayscale ramp (232-255)
local function hex_to_cterm(hex)
    if type(hex) ~= "string" then return nil end
    if #hex == 4 then
	hex = hex:gsub("(%x)", "%1%1")
    end
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    if not (r and g and b) then return nil end

    local levels = { 0, 95, 135, 175, 215, 255 }
    local function cube_index(v)
	if v < 48 then return 0 end
	if v < 115 then return 1 end
	return math.floor((v - 35) / 40)
    end
    local ri, gi, bi = cube_index(r), cube_index(g), cube_index(b)
    local cr, cg, cb = levels[ri + 1], levels[gi + 1], levels[bi + 1]

    local gray_index = math.max(0, math.min(23, math.floor(((r + g + b) / 3 - 3) / 10)))
    local gray = 8 + gray_index * 10

    local function dist(x, y, z)
	return (r - x) ^ 2 + (g - y) ^ 2 + (b - z) ^ 2
    end
    if dist(gray, gray, gray) < dist(cr, cg, cb) then
	return 232 + gray_index
    end
    return 16 + 36 * ri + 6 * gi + bi
end

local orig_create_highlight = hc_utils.create_highlight
hc_utils.create_highlight = function(active_buffer_id, ns_id, data, options)
    local color_value = hc_colors.get_color_value(data.value, 2, options.custom_colors, options.enable_short_hex)
    if color_value ~= nil then
	local group = hc_utils.create_highlight_name(options.render .. data.value .. color_value)
	if options.render == 'background' then
	    local fg = hc_colors.get_foreground_color_from_hex_color(color_value)
	    pcall(vim.api.nvim_set_hl, 0, group, {
		fg = fg,
		bg = color_value,
		ctermfg = hex_to_cterm(fg),
		ctermbg = hex_to_cterm(color_value),
		default = true,
	    })
	else
	    pcall(vim.api.nvim_set_hl, 0, group, {
		fg = color_value,
		ctermfg = hex_to_cterm(color_value),
		default = true,
	    })
	end
    end
    return orig_create_highlight(active_buffer_id, ns_id, data, options)
end
