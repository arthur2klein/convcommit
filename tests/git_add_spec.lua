local git_add = require("convcommit.git_add")

describe("git_add.parse_status", function()
	it("returns an empty list for empty output", function()
		assert.are.same({}, git_add.parse_status(""))
	end)

	it("offers modified, untracked and submodule entries", function()
		local output = " M top.txt\0?? untracked.txt\0 m sub\0"
		assert.are.same({ "top.txt", "untracked.txt", "sub" }, git_add.parse_status(output))
	end)

	it("reports a submodule whose pointer moved", function()
		-- ` M sub` is what `git ls-files -m` used to drop for gitlinks.
		assert.are.same({ "sub" }, git_add.parse_status(" M sub\0"))
	end)

	it("skips entries that are already fully staged", function()
		-- "M " and "A " have a clean worktree (Y == " "), nothing left to add.
		local output = "M  staged.txt\0A  added.txt\0 M dirty.txt\0"
		assert.are.same({ "dirty.txt" }, git_add.parse_status(output))
	end)

	it("keeps staged-then-modified entries", function()
		assert.are.same({ "both.txt" }, git_add.parse_status("MM both.txt\0"))
	end)

	it("offers the destination of a rename and consumes the origin", function()
		local output = "RM new.txt\0old.txt\0 M other.txt\0"
		assert.are.same({ "new.txt", "other.txt" }, git_add.parse_status(output))
	end)

	it("skips a clean rename but still consumes its origin field", function()
		local output = "R  new.txt\0old.txt\0?? extra.txt\0"
		assert.are.same({ "extra.txt" }, git_add.parse_status(output))
	end)

	it("preserves paths containing spaces", function()
		assert.are.same({ "my file.txt" }, git_add.parse_status(" M my file.txt\0"))
	end)
end)
