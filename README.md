# Conventional commit builder for nvim

[![CI](https://github.com/arthur2klein/convcommit/actions/workflows/ci.yml/badge.svg)](https://github.com/arthur2klein/convcommit/actions/workflows/ci.yml)

## Motivation

Creating my own plugin has allowed me to fulfill some of my requirements and preferences:
- Having one plugin to manage basic operations on a git repository (add, commit, push),
- Ensuring consistent presentation between commits,
- Creating new version automatically,
- Adding QOL features for each one with notifications, opening of webpages for new pipelines, …
- Learning along the way.

## Dependencies of the project

This project makes use of several other projects to manage ui:
- MunifTanjim/nui.nvim ⇒ text inputs and popups,
- nvim-telescope/telescope.nvim ⇒ option selection,
- rcarriga/nvim-notify ⇒ notifications.

These dependencies are optional: when one is missing the plugin falls back
to the built-in `vim.ui` equivalents. Note that nui is what enables the
multi-line body popup; without it the body falls back to a single-line
`vim.ui.input`, so multi-paragraph bodies need nui.

## Configuration

### Using Lazy

```lua
{
  "arthur2klein/convcommit",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "rcarriga/nvim-notify",
  },
  config = function()
    local convcommit = require("convcommit")
    convcommit.setup({validate_input_key = "<CR>"})
    vim.keymap.set("n", "<leader>gg", convcommit.create_commit)
    vim.keymap.set("n", "<leader>gv", convcommit.create_version_tag)
    vim.keymap.set("n", "<leader>gV", convcommit.generate_changelog)
    vim.keymap.set("n", "<leader>gp", convcommit.push)
    vim.keymap.set("n", "<leader>ga", convcommit.git_add)
  end,
}
```

## Versioning and changelog

`create_version_tag` stores each release changelog in the **annotated tag
message**, so there is no committed `CHANGELOG.md` and no auto changelog
commit. Rebuild the changelog on demand from those tag messages with
`generate_changelog` (it opens a scratch buffer; nothing is written or
committed).

On a branch other than the default branch it creates a SemVer pre-release
*staging* version `vX.Y.Z-<branch>.<n>`, bumped from the default branch's
latest release (so the base stays stable) where `<n>` counts the tags created
on the branch since it diverged. See the `default_branch` setup option.

## Additional information

For additional information, please refer to the [help](./doc/convcommit.txt) file.

