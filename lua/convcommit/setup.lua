local M = {}

--- True iff nui is available.
---@type boolean
M.has_nui = not pcall(require, "nui")

--- True iff nvim-notify is available.
---@type boolean
M.has_notify = not pcall(require, "notify")

--- True iff telescope is available.
---@type boolean
M.has_telescope = not pcall(require, "telescope")

---@class SetupOptions Options available when setting up the plugin.
---@field commit_types string[] Table of available commit types.
---@field footer_keys string[] Table of available footer keys.
---@field excluded_types string[] Types to exclude from changelog.

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

--- Defines global parameters for the plugin.
---@param options SetupOptions Options available.
function M.setup(options)
	if options["commit_types"] ~= nil then
		M.commit_types = options["commit_types"]
	end
	if options["footer_keys"] ~= nil then
		M.commit_types = options["footer_keys"]
	end
	if options["excluded_type"] ~= nil then
		M.excluded_types = options["excluded_type"]
	end
end

return M
