local setup = require("convcommit.setup")
local has_nui = setup.has_nui
local has_notify = setup.has_notify
local validate_input_key = setup.validate_input_key

local notify = function(message, level)
	if has_notify then
		require("notify")(message, level, { title = "Input" })
	else
		vim.notify(message, level)
	end
end

local M = {}

---@class InputOptions Props for input fields.
---@field prompt string Prompt for the user.
---@field default string | nil (Default to "") Default value if none given.

--- Allows the user to input some information.
--- Pressing C-c will cancel the input as well as the on_submit call.
---@param opts InputOptions Props of the field.
---@param on_submit fun(value: string): nil Action that requires the inputed value.
function M.input(opts, on_submit)
	if has_nui then
		local input = require("nui.input")({
			position = "50%",
			size = {
				width = 60,
				height = 10,
			},
			border = {
				style = "rounded",
				text = {
					top = opts.prompt,
					top_align = "left",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			},
		}, {
			prompt = "> ",
			default_value = opts.default or "",
			on_submit = on_submit,
		})
		input:map("n", "<C-c>", function()
			input:unmount()
			notify("❌ Cancelled.", vim.log.levels.WARN)
		end)
		vim.schedule(function()
			input:mount()
		end)
		input:on(require("nui.utils.autocmd").event.BufEnter, function()
			vim.cmd("startinsert")
		end)
	else
		vim.ui.input(opts, on_submit)
	end
end

--- Allows the user to input multiple lines of information.
--- Pressing <leader><cr> in insert mode insert a line break.
--- Pressing C-c will cancel the input as well as the on_submit call.
---@param opts InputOptions Props of the field.
---@param on_submit fun(value: string): nil Action that requires the inputted value.
function M.multiline_input(opts, on_submit)
	if has_nui then
		local default = opts.default or ""
		local lines = vim.split(default, "\n")
		local popup = require("nui.popup")({
			position = "50%",
			size = {
				width = 80,
				height = 10,
			},
			enter = true,
			focusable = true,
			border = {
				style = "rounded",
				text = {
					top = opts.prompt,
					top_align = "left",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			},
			buf_options = {
				modifiable = true,
				buftype = "acwrite",
			},
		})
		vim.schedule(function()
			popup:mount()
		end)
		vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
		vim.keymap.set("n", validate_input_key, function()
			local result = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
			popup:unmount()
			on_submit(table.concat(result, "\n"))
		end, { buffer = popup.bufnr })
		vim.keymap.set("n", "<C-c>", function()
			popup:unmount()
			notify("❌ Cancelled.", vim.log.levels.WARN)
		end, { buffer = popup.bufnr })
		popup:on(require("nui.utils.autocmd").event.BufEnter, function()
			vim.cmd("startinsert")
		end)
	else
		M.input(opts, on_submit)
	end
end

return M
