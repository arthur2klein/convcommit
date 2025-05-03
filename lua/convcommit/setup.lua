local M = {}

--- True iff nui is available.
---@type boolean
M.has_nui = pcall(require, "nui.input")

--- True iff nvim-notify is available.
---@type boolean
M.has_notify = pcall(require, "notify")

--- True iff telescope is available.
---@type boolean
M.has_telescope = pcall(require, "telescope.pickers")

---@class SetupOptions Options available when setting up the plugin.
---@field commit_types string[]? Table of available commit types.
---@field footer_keys string[]? Table of available footer keys.
---@field excluded_types string[]? Types to exclude from changelog.
---@field validate_input_key string? Key to validate an input.

--- Available types of commits
---@type string[]
M.commit_types = {
	"build",
	"chore",
	"ci",
	"docs",
	"feat",
	"fix",
	"perf",
	"refactor",
	"revert",
	"style",
	"test",
	"merge",
}

--- Available footer keys (other will also be given as an option).
---@type string[]
M.footer_keys = {
	"Changelog-Entry",
	"Release-Note",
	"Co-Author",
	"Ticket-Id",
	"Ticket-Link",
}

--- Types to exclude from changelog.
---@type string[]
M.excluded_types = { "docs", "test", "ci", "merge" }

--- Key to validate multi-line inputs.
---@type string
M.validate_input_key = "<leader><CR>"

--- Defines global parameters for the plugin.
---@param options SetupOptions Options available.
function M.setup(options)
	if options.commit_types ~= nil then
		M.commit_types = options.commit_types
	end
	if options.footer_keys ~= nil then
		M.commit_types = options.footer_keys
	end
	if options.excluded_types ~= nil then
		M.excluded_types = options.excluded_types
	end
	if options.validate_input_key ~= nil then
		M.validate_input_key = options.validate_input_key
	end
end

return M
