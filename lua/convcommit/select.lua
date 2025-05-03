local notify = function(message, level)
	if require("convcommit.setup").has_notify then
		require("notify")(message, level, { title = "Select" })
	else
		vim.notify(message, level)
	end
end

local M = {}

---@class SelectOption Props for a select input.
---@field prompt string Prompt for the user.
---@field default string? Default value if no valid selection.

--- Allows the user to input a value amongst a given list of options.
--- Pressing C-c will cancel the input and the on_choice call.
---@param items string[] Possible choices for the user.
---@param opts SelectOption Props of the input.
---@param on_choice fun(value: string): nil Function that requires the result of the select.
function M.select(items, opts, on_choice)
	if require("convcommit.setup").has_telescope then
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		require("telescope.pickers")
			.new({}, {
				prompt_title = opts.prompt or "Select an option",
				layout_config = { height = 15, width = 50 },
				finder = require("telescope.finders").new_table({
					results = items,
				}),
				sorter = require("telescope.config").values.generic_sorter({}),
				attach_mappings = function(_, map)
					actions.select_default:replace(function(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection then
							on_choice(selection[1])
						else
							if opts.default ~= nil then
								on_choice(opts.default)
							else
								notify("❌ Cancelled.", vim.log.levels.WARN)
							end
						end
					end)
					map("i", "<C-c>", actions.close)
					map("n", "<C-c>", actions.close)
					return true
				end,
			})
			:find()
	else
		vim.ui.select(items, opts, on_choice)
	end
end

return M
