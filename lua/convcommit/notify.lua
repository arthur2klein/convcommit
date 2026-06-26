local M = {}

--- Creates a notification function bound to the given title.
--- Uses nvim-notify when available, falling back to vim.notify.
---@param title string Title shown on the notification.
---@return fun(message: string, level: integer?): nil
function M.with_title(title)
	return function(message, level)
		if require("convcommit.setup").has_notify then
			require("notify")(message, level, { title = title })
		else
			vim.notify(message, level)
		end
	end
end

return M
