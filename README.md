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
    vim.keymap.set("n", "<leader>gg", convcommit.create_commit)
    vim.keymap.set("n", "<leader>gv", convcommit.create_version_tag)
    vim.keymap.set("n", "<leader>gp", convcommit.push)
    vim.keymap.set("n", "<leader>ga", convcommit.git_add)
  end,
}
```

## Additional information

For additional information, please refer to the [help](./doc/convommit.txt) file.

