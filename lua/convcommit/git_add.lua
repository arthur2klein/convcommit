local M = {}

--- Split a NUL-separated string into its fields.
--- Uses plain (non-pattern) find so it works with embedded zero bytes across
---@param s string NUL-separated string, each field ending with a NUL.
---@return string[] fields The fields, without their trailing NUL.
local function split_nul(s)
  local fields = {}
  local start = 1
  while true do
    local nul = s:find("\0", start, true)
    if not nul then
      if start <= #s then
        table.insert(fields, s:sub(start))
      end
      break
    end
    table.insert(fields, s:sub(start, nul - 1))
    start = nul + 1
  end
  return fields
end

--- Parse the output of `git status --porcelain=v1 -z` into the list of paths
--- that still have something to stage.
---@param output string Raw output of `git status --porcelain=v1 -z`.
---@return string[] files Paths ready to be staged.
function M.parse_status(output)
  local fields = split_nul(output)
  local files = {}
  local i = 1
  while i <= #fields do
    local entry = fields[i]
    i = i + 1
    local x = entry:sub(1, 1)
    local y = entry:sub(2, 2)
    local path = entry:sub(4)
    -- Rename/copy stores the origin path in the next field.
    if x == "R" or x == "C" then
      i = i + 1
    end
    if y ~= " " and path ~= "" then
      table.insert(files, path)
    end
  end
  return files
end

if not require("convcommit.setup").has_telescope then
  M.git_add = function() end
  return M
end
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local previewers = require("telescope.previewers")
local action_state = require("telescope.actions.state")

--- Displays a telescope picker to add files.
--- Press y to add a file, and n to skip it.
function M.git_add()
  local output = vim.fn.system({ "git", "status", "--porcelain=v1", "-z", "--untracked-files=all" })
  local files = M.parse_status(output)
  local function refresh_picker(picker, new_results)
    picker:refresh(
      finders.new_table({
        results = new_results,
      }),
      { reset_prompt = false }
    )
  end
  --- Drop the current entry from the picker and close it once the list is empty.
  local function skip_current(prompt_bufnr, picker)
    local entry = action_state.get_selected_entry()
    local file = entry[1]
    for i, f in ipairs(files) do
      if f == file then
        table.remove(files, i)
        break
      end
    end
    refresh_picker(picker, files)
    if #files == 0 then
      actions.close(prompt_bufnr)
    end
  end
  pickers
      .new({}, {
        prompt_title = "Stage Files (y = stage, n = skip)",
        finder = finders.new_table({
          results = files,
        }),
        sorter = conf.generic_sorter({}),
        previewer = previewers.git_file_diff.new({}),
        attach_mappings = function(prompt_bufnr, map)
          local picker = action_state.get_current_picker(prompt_bufnr)
          map("i", "y", function()
            local entry = action_state.get_selected_entry()
            vim.fn.system({ "git", "add", entry[1] })
            skip_current(prompt_bufnr, picker)
          end)
          map("i", "n", function()
            skip_current(prompt_bufnr, picker)
          end)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
          end)
          return true
        end,
      })
      :find()
end

return M
