local M = {}

function M.to_string(value)
	local type_value = type(value)
	if type_value == "nil" then
		return "nil"
	elseif type_value == "number" then
		return string.format("%s", value)
	elseif type_value == "string" then
		return string.format("'%s'", string.gsub(value, "'", "\\'"))
	elseif type_value == "boolean" then
		return value and "true" or "false"
	elseif type_value == "table" then
		local lines = {}
		for index, item in ipairs(value) do
			table.insert(lines, index .. " = " .. M.to_string(item))
		end
		return "{" .. table.concat(lines, ", ") .. "}"
	elseif type_value == "function" or type_value == "thread" or type_value == "userdata" then
		return string.format("<%s: %s>", type_value, tostring(value))
	else
		return "<unknown type>"
	end
end

return M
