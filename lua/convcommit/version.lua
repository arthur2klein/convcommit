local M = {}

local notify = function(message, level)
	if require("convcommit.setup").has_nui then
		require("notify")(message, level, { title = "Version" })
	else
		vim.notify(message, level)
	end
end
local excluded_types = require("convcommit.setup").excluded_types

--- Returns the latest release tag reachable from the given ref.
--- Tags that contain "#" (staging tags) are excluded so the base
--- version stays stable across staging builds.
--- @param ref string|nil Ref to describe from (defaults to HEAD).
--- @return string | nil: Latest release tag, or nil if none.
local function get_latest_tag(ref)
	local cmd = "git describe --tags --abbrev=0 --exclude '*#*'"
	if ref and ref ~= "" then
		cmd = cmd .. " " .. ref
	end
	local tag = vim.fn.system(cmd):gsub("%s+", "")
	if tag ~= "" and tag:sub(0, 5) ~= "fatal" then
		return tag
	else
		return nil
	end
end

--- Returns the name of the current branch (or "HEAD" when detached).
--- @return string: Current branch name.
local function get_current_branch()
	return (vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("%s+", ""))
end

--- Determines the repository default branch. Uses the configured value
--- when set, otherwise the remote HEAD (origin/HEAD), then main/master.
--- @return string: Default branch name.
local function get_default_branch()
	local configured = require("convcommit.setup").default_branch
	if configured and configured ~= "" then
		return configured
	end
	local ref = vim.fn.system("git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null"):gsub("%s+", "")
	if ref ~= "" and not ref:match("fatal") then
		return (ref:gsub("^origin/", ""))
	end
	for _, name in ipairs({ "main", "master" }) do
		vim.fn.system("git rev-parse --verify --quiet " .. name)
		if vim.v.shell_error == 0 then
			return name
		end
	end
	return "master"
end

--- Resolves a branch name to a usable ref, preferring the remote-tracking
--- ref (origin/<name>) when it exists so divergence is measured against
--- the published default branch.
--- @param name string Branch name.
--- @return string: Resolved ref.
local function resolve_ref(name)
	vim.fn.system("git rev-parse --verify --quiet origin/" .. name)
	if vim.v.shell_error == 0 then
		return "origin/" .. name
	end
	return name
end

--- Counts the tags reachable from HEAD but not from the given ref, i.e.
--- the tags created on the current branch since it diverged.
--- @param ref string Ref of the default branch.
--- @return integer: Number of tags since divergence.
local function count_tags_since_divergence(ref)
	local out = vim.fn.system(string.format("git tag --merged HEAD --no-merged %s", ref))
	if vim.v.shell_error ~= 0 then
		return 0
	end
	local count = 0
	for line in out:gmatch("[^\r\n]+") do
		if line:gsub("%s+", "") ~= "" then
			count = count + 1
		end
	end
	return count
end

--- Sanitizes a branch name into a SemVer-legal pre-release identifier
--- (only [0-9A-Za-z-] is allowed; everything else becomes "-").
--- @param name string Branch name.
--- @return string: Sanitized branch name.
local function sanitize_branch(name)
	return (name:gsub("[^%w-]", "-"))
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

local function update_swagger_version(version)
	local swaggerFiles = {
		"swagger.yaml",
		"swagger.yml",
		"openapi.yaml",
		"openapi.yml",
		"swagger/main.yaml",
		"swagger/main.yml",
		"swagger/swagger.yaml",
		"swagger/swagger.yml",
		"docs/swagger.yaml",
		"docs/swagger.yml",
		"docs/openapi.yaml",
		"docs/openapi.yml",
		"doc/swagger.yaml",
		"doc/swagger.yml",
		"doc/openapi.yaml",
		"doc/openapi.yml",
	}
	local function fileExists(path)
		local f = io.open(path, "r")
		if f then
			f:close()
			return true
		else
			return false
		end
	end
	local function readFile(path)
		local f = assert(io.open(path, "r"))
		local content = f:read("*all")
		f:close()
		return content
	end
	local function writeFile(path, content)
		local f = assert(io.open(path, "w"))
		f:write(content)
		f:close()
	end
	for _, filename in ipairs(swaggerFiles) do
		if fileExists(filename) then
			notify("Found swagger file: " .. filename, vim.log.levels.INFO)
			local content = readFile(filename)
			local updated, count =
				content:gsub("(%f[%w]version:%s*['\"]?)([%w%p]+)(['\"]?)", "%1" .. version .. "%3", 1)
			if count > 0 then
				writeFile(filename, updated)
				notify("Updated version to " .. version .. " in " .. filename, vim.log.levels.INFO)
				vim.fn.system("git add " .. filename)
				return true
			else
				notify("No version field found in " .. filename, vim.log.levels.ERROR)
			end
		end
	end
	notify("No Swagger file found or no version field updated.", vim.log.levels.INFO)
	return false
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

--- Creates a tag and pushes it to the remote. When a message is given the
--- tag is annotated and the message (the changelog for this version) is
--- stored in the tag object itself, so no changelog file or commit is
--- needed. The message is passed over stdin to avoid shell quoting issues.
---@param tag string Tag to create.
---@param message string|nil Annotation message; nil/"" creates a lightweight tag.
---@param remote string | nil (Defaults to origin) Remote to push the tag to.
---@return string: Output of the tag creation and push.
local function create_tag(tag, message, remote)
	remote = remote or "origin"
	local out
	if message and message ~= "" then
		-- verbatim cleanup so markdown "#" headers are not stripped as comments.
		out = vim.fn.system({ "git", "tag", "-a", tag, "--cleanup=verbatim", "-F", "-" }, message)
	else
		out = vim.fn.system({ "git", "tag", tag })
	end
	if vim.v.shell_error ~= 0 then
		return out
	end
	return out .. vim.fn.system({ "git", "push", remote, tag })
end

--- Displays information about the tag creation. The confirmed changelog
--- becomes the annotated tag's message. A release commit is created only
--- when a swagger version field was actually bumped (it has to be
--- committed to be captured by the tag); the changelog never is.
---@param version string New version tag to create.
---@param entries string[] List of changelog entries for this version.
local function ask_for_confirmation(version, entries)
	require("convcommit.input").multiline_input(
		{ prompt = "Confirm changelog (stored in the tag message):", default = M.build_changelog(version, entries) },
		function(message)
			if update_swagger_version(version) then
				vim.fn.system({ "git", "commit", "-m", string.format("chore(release): bump version to %s", version) })
			end
			notify(create_tag(version, message), vim.log.levels.INFO)
			notify("✅ Version " .. version .. " tagged (changelog in tag message)!", vim.log.levels.INFO)
		end
	)
end

--- Rebuilds the full changelog on demand from annotated release tags and
--- opens it in a throwaway markdown scratch buffer (nothing is written to
--- disk or committed). Pre-release / staging tags (those containing "-")
--- are skipped. Save the buffer manually if you want a file.
function M.generate_changelog()
	local tags_out = vim.fn.system({ "git", "tag", "--list", "--sort=-creatordate" })
	if vim.v.shell_error ~= 0 then
		notify("Failed to list tags", vim.log.levels.ERROR)
		return
	end
	local sections = {}
	for tag in tags_out:gmatch("[^\r\n]+") do
		tag = tag:gsub("%s+$", "")
		if tag ~= "" and not tag:find("-", 1, true) then
			local body = vim.fn.system({ "git", "tag", "-l", "--format=%(contents)", tag })
			body = body:gsub("^%s+", ""):gsub("%s+$", "")
			if body ~= "" then
				table.insert(sections, body)
			end
		end
	end
	if #sections == 0 then
		notify("No annotated release tags found", vim.log.levels.WARN)
		return
	end
	local content = table.concat(sections, "\n\n\n")
	vim.cmd("enew")
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.filetype = "markdown"
	vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n", { plain = true }))
	notify(string.format("Changelog rebuilt from %d release tags", #sections), vim.log.levels.INFO)
end

--- Determines the new version from the latest tag and commits done since, asks for confirmation,
--- and creates the new version tag and changelog file.
---
--- On a non-default branch the version is a staging version: the base
--- bump is computed from the latest release tag on the default branch
--- (so it stays stable across staging builds) and is suffixed with the
--- SemVer pre-release "-<branch>.<n>", where <n> is the number of tags
--- created on the branch since it diverged from the default branch.
--- Staging versions only create the tag, they do not touch the changelog.
function M.create_version_tag()
	local default_branch = get_default_branch()
	local current_branch = get_current_branch()
	local is_staging = current_branch ~= "" and current_branch ~= "HEAD" and current_branch ~= default_branch
	local default_ref = is_staging and resolve_ref(default_branch) or nil

	-- Base the bump on the latest release: nearest tag on the default
	-- branch for staging, nearest reachable tag otherwise.
	local base_tag = is_staging and get_latest_tag(default_ref) or get_latest_tag()
	local commits = get_changelog_entries_since(base_tag)
	if #commits == 0 then
		notify("No new commits since " .. (base_tag or "nil"), vim.log.levels.ERROR)
		return
	end
	local bump = M.determine_bump(commits)
	local new_version = M.bump_version(base_tag, bump)

	if is_staging then
		local count = count_tags_since_divergence(default_ref)
		new_version = string.format("%s-%s.%d", new_version, sanitize_branch(current_branch), count)
		-- Staging build: tag only, no changelog churn.
		if vim.fn.confirm("Create staging tag " .. new_version .. "?", "&Yes\n&No", 1) ~= 1 then
			notify("Aborted", vim.log.levels.INFO)
			return
		end
		notify(create_tag(new_version), vim.log.levels.INFO)
		notify("✅ Staging version " .. new_version .. " tagged!", vim.log.levels.INFO)
		return
	end

	ask_for_confirmation(new_version, commits)
end

return M
