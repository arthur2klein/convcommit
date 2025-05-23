local M = {}

local notify = function(message, level)
	if require("convcommit.setup").has_nui then
		require("notify")(message, level, { title = "Version" })
	else
		vim.notify(message, level)
	end
end
local excluded_types = require("convcommit.setup").excluded_types

--- Returns the latest tag of the given project.
--- @return string | nil: Latest tag of the given project.
local function get_latest_tag()
	local tag = vim.fn.system("git describe --tags --abbrev=0"):gsub("%s+", "")
	if tag ~= "" and tag:sub(0, 5) ~= "fatal" then
		return tag
	else
		return nil
	end
end

--- Checks whether a given commit should be automatically rejected from the changelog.
---@param commit string Commit to check.
---@return boolean: True iff the commit can be included in the changelog.
function M.should_be_included_in_changelog(commit)
	local is_excluded = false
	for _, prefix in ipairs(excluded_types) do
		if string.sub(commit, 1, #prefix) == prefix then
			is_excluded = true
			break
		end
	end
	return not is_excluded
end

--- Returns the list of changelog entries from commits after the given tag.
--- Entries are taken from the Changelog-Entry footer, or the first line if no such footer.
---@param tag string|nil: Tag after which to return commits, or nil to take all.
---@return string[]: List of changelog entries or commit subjects.
local function get_changelog_entries_since(tag)
	local delimiter = "====BETWEEN_COMMITS===="
	local range
	if tag == nil then
		range = "HEAD"
	else
		range = tag .. "..HEAD"
	end
	local format = "%s%n%b%n" .. delimiter
	local cmd = string.format("git log --no-merges %s --pretty=format:%s", range, format)
	local raw_output = vim.fn.system(cmd)
	local entries = {}
	for commit in string.gmatch(raw_output, "(.-)" .. delimiter) do
		local changelog_entry = commit:match("[Cc]hangelog%-[Ee]ntry:%s*(.+)")
		if changelog_entry then
			table.insert(entries, changelog_entry)
		else
			local subject = commit:match("([^%s].-)\n") or commit
			if M.should_be_included_in_changelog(subject) then
				table.insert(entries, subject)
			end
		end
	end
	return entries
end

--- Determines the type of version bump from the given list of commit.
---@param commits string[] List of commits for the new version.
---@return string: Type of version bump amongst patch, minor and major.
function M.determine_bump(commits)
	local bump = "patch"
	for _, c in ipairs(commits) do
		if c:match("BREAKING CHANGE") then
			return "major"
		elseif c:match("^feat") then
			bump = "minor"
		end
	end
	return bump
end

--- Determines the new version tag after the given one for the given level of bump.
--- If no previous version, v0.0.0 will be returned.
---@param version string|nil Previous version tag.
---@param level string Level of bump amongst patch, minor and major.
---@return string: New version tag.
function M.bump_version(version, level)
	if version == nil then
		return "v0.0.0"
	end
	local major, minor, patch = version:match("v?(%d+)%.(%d+)%.(%d+)")
	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
	if level == "major" then
		major = major + 1
		minor = 0
		patch = 0
	elseif level == "minor" then
		minor = minor + 1
		patch = 0
	else
		patch = patch + 1
	end
	return string.format("v%d.%d.%d", major, minor, patch)
end

--- Returned generated content for the changelog file.
---@param new_version string New version tag.
---@param entries string[] List of entries to write in the changelog.
---@return string: Generated content of the changelog.
function M.build_changelog(new_version, entries)
	local message = "## " .. new_version .. " - " .. os.date("%Y-%m-%d") .. "\n\n"
	for _, c in ipairs(entries) do
		message = message .. "- " .. c .. "\n"
	end
	return message
end

--- Creates a CHANGELOG.md file for the given version and appends the given content.
---@param content string Content to add to the file.
local function write_changelog(content)
	local f = io.open("CHANGELOG.md", "a")
	if not f then
		notify("Error creating the changelog file", vim.log.levels.ERROR)
		return
	end
	f:write(content .. "\n\n\n")
	f:close()
end

--- Creates and push a commit to document the addition of a changelog entry.
---@param new_version string Version added to the changelog.
local function commit_changelog(new_version)
	vim.fn.system(
		'git add CHANGELOG.md && git commit -m "docs(CHANGELOG.md): Add changelog for version ' .. new_version .. '"'
	)
end

--- Creates the given tag, and pushes it to the remote
---@param tag string Tag to create.
---@param remote string | nil (Defaults to origin) Remote to push the tag to (--all for all).
---@return string: Output of the tag creation.
local function create_tag(tag, remote)
	if remote == nil then
		remote = "origin"
	end
	return vim.fn.system(string.format("git tag %s && git push %s %s", tag, remote, tag))
end

--- Displays information about the tag creation.
---@param version string New version tag to create.
---@param entries string[] List of entries to add in the CHANGELOG.md file.
local function ask_for_confirmation(version, entries)
	require("convcommit.input").multiline_input(
		{ prompt = "Confirm message:", default = M.build_changelog(version, entries) },
		function(message)
			write_changelog(message)
			commit_changelog(version)
			notify(create_tag(version), vim.log.levels.INFO)
			notify("✅ Changelog created!", vim.log.levels.INFO)
		end
	)
end

--- Determines the new version from the latest tag and commits done since, asks for confirmation,
--- and creates the new version tag and changelog file.
function M.create_version_tag()
	local latest_tag = get_latest_tag()
	local commits = get_changelog_entries_since(latest_tag)
	if #commits == 0 then
		notify("No new commits since " .. (latest_tag or "nil"), vim.log.levels.ERROR)
		return
	end
	local bump = M.determine_bump(commits)
	local new_version = M.bump_version(latest_tag, bump)
	ask_for_confirmation(new_version, commits)
end

return M
