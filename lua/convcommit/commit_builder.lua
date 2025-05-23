local CommitBuilder = {}

--- Structure to hold commit metadata
---@class CommitBuilder
---@field type string Type of the ticket (eg. feat, fix, docs, test, ...)
---@field scope string|nil Scope of the ticket, should be a name.
---@field subject string Main, short description of the commit.
---@field body string|nil Longer optional description of the commit.
---@field footers string[] Footers of the commit.
---@field breaking string|nil Information about the breaking nature of the commit, if any.
---@field ticket_id string|nil Id of the related ticket if any.
---@field ticket_link string|nil Link of the related ticket if any.

--- Creates a new empty commit.
---@return CommitBuilder: Empty commit with required fields initialized.
function CommitBuilder.new()
	local self = {
		type = "feat",
		subject = "No message",
		footers = {},
		scope = nil,
		body = nil,
		breaking = nil,
		ticket_id = nil,
		ticket_link = nil,
	}
	return self
end

--- Adds wrapping to the given string.
---@param text string String to add wrapping to.
---@param width integer? Number of columns of a row. Defaults to 80.
---@return string: Text wrapped with the given max number of columns.
local function wrap_text(text, width)
	width = width or 80
	local wrapped = {}
	for line in text:gmatch("[^\n]+") do
		local current = ""
		for word in line:gmatch("%S+") do
			if #current + #word + 1 > width and #current > 0 then
				table.insert(wrapped, current)
				current = word
			else
				current = current == "" and word or (current .. " " .. word)
			end
		end
		table.insert(wrapped, current)
	end
	return table.concat(wrapped, "\n")
end

--- Extracts and returns the ticket id from the given ticket link.
---@param link string: Link to the issue.
---@param type string: Type of the ticket amongst jira, gitlab and github.
---@return string|nil: Id of the ticket, or nil if unrecognized type.
local function ticket_id_from_link(link, type)
	if type == "jira" then
		-- Example: https://<domain>.atlassian.net/browse/PROJ-123
		-- Example: https://<domain>.atlassian.net/issues/PROJ-123
		local value = link:match("/browse/([A-Z]+%-%d+)")
		return (value and #value > 0) and value or link:match("/issues/([A-Z]+%-%d+)")
	elseif type == "gitlab" then
		-- Example: https://gitlab.com/<group>/<project>/-/issues/456
		return "#" .. link:match("/issues/(%d+)")
	elseif type == "github" then
		-- Example: https://github.com/<user>/<repo>/issues/789
		return "#" .. link:match("/issues/(%d+)")
	else
		return nil
	end
end

--- Sets the link and ticket id of the given commit.
---@param self CommitBuilder: Commit to set the ticket of.
---@param link string: Link the the ticket related to the commit.
---@param type string: Type of the ticket amongst jira, gitlab and github.
---@return nil
function CommitBuilder.setTicket(self, link, type)
	self.ticket_link = link
	self.ticket_id = ticket_id_from_link(link, type)
end

--- Adds a footer the the given commit.
---@param self CommitBuilder: Commit to add a footer to.
---@param footer string: Footer to add.
function CommitBuilder.add_footer(self, footer)
	table.insert(self.footers, footer)
end

--- Checks if a given footer is already defined.
---@param self CommitBuilder: Data of the commit.
---@param footer_key string: Key to search.
---@return boolean: True iff the footer already contains the given key.
local function contains_footer(self, footer_key)
	for _, str in ipairs(self.footers) do
		if str:sub(1, #footer_key) == footer_key then
			return true
		end
	end
	return false
end

--- Creates the commit from the given data
---@param self CommitBuilder: Data of the commit to create.
---@return string: Commit message for the given commit.
function CommitBuilder.build(self)
	if not contains_footer(self, "Ticket-Id") and self.ticket_id and #self.ticket_id > 0 then
		self.subject = string.format("[%s] %s", self.ticket_id, self.subject)
		table.insert(self.footers, string.format("Ticket-Id: %s", self.ticket_id))
	end
	if not contains_footer(self, "Ticket-Link") and self.ticket_link and #self.ticket_link > 0 then
		table.insert(self.footers, string.format("Ticket-Link: %s", self.ticket_link))
	end
	if self.scope then
		self.type = string.format("%s(%s)", self.type, self.scope)
	end
	if self.breaking then
		self.type = self.type .. "!"
		table.insert(self.footers, 1, string.format("BREAKING CHANGE: %s\n", self.breaking))
	end
	local message = string.format("%s: %s", self.type, self.subject)
	if self.body and #self.body > 0 then
		message = message .. "\n\n" .. wrap_text(self.body)
	end
	if self.footers and #self.footers > 0 then
		message = message .. "\n\n" .. table.concat(self.footers, "\n")
	end
	return message
end

return CommitBuilder
