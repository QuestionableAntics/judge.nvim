# Description
Who better to preside over your sessions than a judge?

Judge is a minimal session management plugin that is 100% based around my own means of navigating projects.

# Installation
The normal methods

## Lazy

```lua
{
    'questionableantics/judge.nvim',
    dependencies = {
        'nvim-telescope/telescope.nvim',
    }
}
```


# Requirements
If you want to be able to select sessions to delete and switch to from a picker, you'll need telescope.nvim

# Performance
It loads quick enough (never more than a millisecond according to Lazy Profile)

# How to use
There are a few functions exposed that you can bind your own keymappings to

## `save_session`
Persists your current session

```lua
require('judge.nvim').save_session()
```


## `delete_session`
Deletes your current session. Accepts an optional `session_name` parameter, defaulting to your current session if one is not passed in.

```lua
require('judge.nvim').delete_session()
```


## `search_switch_sessions`
Open a telescope picker for your existing sessions

```lua
require('judge.nvim').search_switch_sessions()
```


## `search_delete_session`
Open a telescope picker to delete from your existing sessions

```lua
require('judge.nvim').search_delete_sessions()
```


## `go_to_previous_session`
Convenience method to open the session you last switched from.

Does not trigger if this is the first session since opening Neovim

```lua
require('judge.nvim').go_to_previous_session()
```
