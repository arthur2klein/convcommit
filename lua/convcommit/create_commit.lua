local M = {}

local input = require("convcommit.input").input
local multiline = require("convcommit.input").multiline_input
local select = require("convcommit.select").select
local commit_builder = require("convcommit.commit_builder")
local notify = function(message, level)
	if require("convcommit.setup").has_notify then
		require("notify")(message, level, { title = "Commit" })
	else
		vim.notify(message, level)
	end
end
local unpack = table.unpack or unpack

---@type CommitBuilder
local builder

--- Displays the commit message a last time, allowing for modifications before creating the commit.
local function preview()
	multiline({ prompt = "Confirm message:", default = commit_builder.build(builder) }, function(message)
		vim.fn.system(string.format('git commit -m "%s"', message))
		local status = vim.v.shell_error
		if status == 0 then
			notify("✅ Commit created!", vim.log.levels.INFO)
		elseif status == 1 then
			notify("❌ Commit received failure!", vim.log.levels.ERROR)
		elseif status == 128 then
			notify("❌ Commit received fatal error!", vim.log.levels.ERROR)
		else
			notify("❌ Commit received an other error!", vim.log.levels.ERROR)
		end
	end)
end

--- Adds footers recursively
local function add_footer()
	local footers = { unpack(require("convcommit.setup").footer_keys) }
	table.insert(footers, 1, "End creation")
	table.insert(footers, "Other")
	select(footers, { prompt = "Add a footer:", default = "End creation" }, function(key)
		if key == "End creation" then
			preview()
		elseif key == "Other" then
			input({ prompt = 'Enter your full footer in "key: value" format:' }, function(new_footer)
				new_footer = vim.trim(new_footer)
				if new_footer ~= "" then
					commit_builder.add_footer(builder, new_footer)
				else
					notify("Could not add an empty footer.", vim.log.levels.WARN)
				end
				add_footer()
			end)
		else
			input({ prompt = string.format("Value for footer %s:", key) }, function(value)
				value = vim.trim(value)
				commit_builder.add_footer(builder, string.format("%s: %s", key, value))
				add_footer()
			end)
		end
	end)
end

--- Asks if the commit is breaking, and asks for additional information.
--- This will add a ! in the first line, as well as a BREAKING CHANGE footer.
local function ask_breaking_change()
	select({ "No", "Yes" }, { prompt = "Is this a breaking change?", default = "No" }, function(choice)
		if choice == "Yes" then
			input({ prompt = "Describe the breaking change:" }, function(breaking_desc)
				builder.breaking = breaking_desc
				add_footer()
			end)
		else
			builder.breaking = nil
			add_footer()
		end
	end)
end

--- Enters the longer optional commit description.
local function enter_body()
	multiline({ prompt = "Enter commit body (optional):", default = "" }, function(body)
		builder.body = body
		ask_breaking_change()
	end)
end

--- Enters the commit subject: short, main description of the commit.
local function enter_subject()
	input({ prompt = "Enter commit subject:" }, function(subject)
		if not subject or subject == "" then
			notify("❌ Commit cancelled.", vim.log.levels.ERROR)
		end
		builder.subject = subject
		enter_body()
	end)
end

--- Inputs the optional scope of the commit.
--- Acceptable values are amongst the part of path of staged changes.
local function select_scope()
	local scopes = vim.fn.systemlist("git diff --name-only --cached | sed 's:\\.[^/]*::g' | sed 's:/:\\n:g' | sort -u")
	table.insert(scopes, "none")
	select(scopes, { prompt = "Select scope (or none):", default = "none" }, function(choice)
		if choice ~= "none" then
			builder.scope = choice
		else
			builder.scope = nil
		end
		enter_subject()
	end)
end

--- Inputs the commit type.
--- Affects the first line of the commit.
--- Acceptable values are: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test,
--- merge
local function select_commit_type()
	select(
		require("convcommit.setup").commit_types,
		{ prompt = "Select commit type:", default = "fix" },
		function(choice)
			if not choice or choice == "" then
				notify("❌ Commit cancelled.", vim.log.levels.ERROR)
			else
				builder.type = choice
				select_scope()
			end
		end
	)
end

--- Creates the ticket information knowing the source of the ticket.
---@param type string Type of the ticket amongst jira, github and gitlab.
local function input_ticket(type)
	input({ prompt = string.format("Enter %s ticket link:", type) }, function(link)
		if not link or link == "" then
			notify("❌ Commit cancelled.", vim.log.levels.ERROR)
		end
		commit_builder.setTicket(builder, link, type)
		select_commit_type()
	end)
end

--- Gets information about the related ticket.
--- Affects the subject, Ticket-Id and Ticket-Link footer.
local function get_ticket_info()
	local ticket_options = {
		"none",
		"jira",
		"github",
		"gitlab",
	}
	select(ticket_options, { prompt = "Ticket", default = "none" }, function(choice)
		if choice and #choice ~= 0 and choice ~= "none" then
			input_ticket(choice)
		else
			select_commit_type()
		end
	end)
end

--- Performs some preliminary checks for requirements to be able to create a commit.
--- Also logs the reason for the failure.
--- Checks the following:
--- - in a git repo,
--- - not in merge conflict,
--- - some changes are staged,
--- - git configured.
---@return boolean is_successful true iff all checks pass
local function preliminary_checks()
	-- Check if inside a Git repo
	local git_root = vim.fn.system("git rev-parse --is-inside-work-tree")
	if vim.v.shell_error ~= 0 or not git_root:match("true") then
		notify("Not inside a Git repository.", vim.log.levels.ERROR)
		return false
	end
	-- Check for merge conflicts
	local merge_state = vim.fn.system("git rev-parse --git-path MERGE_HEAD")
	if vim.fn.filereadable(vim.fn.trim(merge_state)) == 1 then
		notify("Merge in progress. Please resolve conflicts before committing.", vim.log.levels.ERROR)
		return false
	end
	-- Check for staged changes
	local diff_status = vim.fn.system("git diff --cached --name-only")
	if vim.trim(diff_status) == "" then
		notify("No staged changes to commit.", vim.log.levels.ERROR)
		return false
	end
	-- Optional: Check if Git user config is set
	local user_name = vim.fn.system("git config user.name")
	local user_email = vim.fn.system("git config user.email")
	if vim.trim(user_name) == "" or vim.trim(user_email) == "" then
		notify("Git user.name or user.email is not set. Please configure Git.", vim.log.levels.ERROR)
		return false
	end
	return true
end

--- Ask for information to build a commit for the currently staged changes.
function M.create_commit()
	if preliminary_checks() then
		builder = commit_builder.new()
		get_ticket_info()
	end
end

return M
