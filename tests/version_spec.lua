local version = require("convcommit.version")

describe("version module", function()
	describe("bump_version", function()
		it("returns v0.0.0 if no previous version", function()
			assert.are.equal("v0.0.0", version.bump_version(nil, "patch"))
		end)

		it("correctly bumps patch", function()
			assert.are.equal("v1.2.4", version.bump_version("v1.2.3", "patch"))
		end)

		it("correctly bumps minor", function()
			assert.are.equal("v1.3.0", version.bump_version("v1.2.3", "minor"))
		end)

		it("correctly bumps major", function()
			assert.are.equal("v2.0.0", version.bump_version("v1.2.3", "major"))
		end)
	end)

	describe("determine_bump", function()
		it("detects major bump when BREAKING CHANGE is present", function()
			local commits = { "fix: something", "BREAKING CHANGE: big change" }
			assert.are.equal("major", version.determine_bump(commits))
		end)

		it("detects minor bump when feat commit is present", function()
			local commits = { "feat: add new feature", "fix: minor fix" }
			assert.are.equal("minor", version.determine_bump(commits))
		end)

		it("defaults to patch", function()
			local commits = { "fix: small fix", "chore: update deps" }
			assert.are.equal("patch", version.determine_bump(commits))
		end)
	end)

	describe("should_be_included_in_changelog", function()
		it("excludes commits starting with excluded types", function()
			assert.is_false(version.should_be_included_in_changelog("docs: update README"))
			assert.is_false(version.should_be_included_in_changelog("test: add new tests"))
			assert.is_false(version.should_be_included_in_changelog("ci: update CI config"))
			assert.is_false(version.should_be_included_in_changelog("merge branch 'main'"))
		end)

		it("includes other commits", function()
			assert.is_true(version.should_be_included_in_changelog("fix: fix bug"))
			assert.is_true(version.should_be_included_in_changelog("feat: add new feature"))
		end)
	end)

	describe("build_changelog", function()
		it("builds a formatted changelog", function()
			local entries = { "feat: add feature", "docs: should not be included", "fix: fix bug" }
			local result = version.build_changelog("v1.2.3", entries)
			assert.are.equal("## v1.2.3", result:match("## v1.2.3"))
			assert.are.equal("- feat: add feature", result:match("%- feat: add feature"))
			assert.are.equal("- fix: fix bug", result:match("%- fix: fix bug"))
		end)
	end)
end)
