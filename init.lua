------------------------------------------------------------
-- Utils
------------------------------------------------------------

local utils = {}

function utils.build_session_path(opts)
	return opts.session_dir .. "/" .. opts.session_name
end

function utils.update_session_state(state, opts)
	state.previous_session_name = state.session_name
	state.session_name = opts.session_name
	state.session_path = utils.build_session_path({
		session_dir = opts.session_dir,
		session_name = state.session_name,
	})

	return state
end

function utils.should_save(opts)
	local cwd = vim.fn.getcwd()

	-- if neovim was called with a path to a specifc file, don't write session
	if opts.ignore_argv and vim.fn.argc() > 0 then
		return false
	end

	-- if the current directory is in the ignored directories, don't save session
	for _, ignored_directory in ipairs(opts.ignored_directories) do
		if cwd == ignored_directory then
			return false
		end
	end

	return true
end

function utils.should_load(opts)
	-- if neovim was called with a path to a specific file, don't write session
	if opts.ignore_argv and vim.fn.argc() > 0 then
		return false
	end

	-- if the current session is the same as the session that is about to be loaded, don't bother
	if JudgeState.session_name == opts.session_name then
		return false
	end

	-- if the session file doesn't exist, don't load it
	if vim.fn.filereadable(JudgeState.session_path) == 0 then
		return false
	end

	return true
end

function utils.cleanup_buffers(opts)
	if not opts.ignored_buffer_patterns then
		return
	end

	local buffers = vim.api.nvim_list_bufs()

	-- for all open buffers
	for _, buffer in ipairs(buffers) do
		local buffer_name = vim.fn.expand("#" .. buffer .. ":~")

		-- if the buffer matches an ignored pattern, delete it
		for _, ignored_buffer_pattern in ipairs(opts.ignored_buffer_patterns) do
			if string.find(buffer_name, ignored_buffer_pattern) then
				vim.api.nvim_buf_delete(buffer, { force = true })
			end
		end
	end
end

------------------------------------------------------------
--- Judge
------------------------------------------------------------

local M = {}
JudgeState = {}

M.opts = {
	-- directories that should not have sessions persisted
	ignored_directories = {},
	-- close all buffers matching this pattern when saving a session
	ignored_buffer_patterns = {},
	-- don't save session if neovim was called with a path to a specific file
	ignore_argv = true,
	-- directory to save sessions in
	session_dir = vim.fn.expand("$HOME/.nvim/sessions"),
	-- executed before saving a session
	-- accepts judge's current state as an argument
	pre_load_hook = function(_) end,
	-- executed after loading a session
	-- accepts judge's current state as an argument
	post_load_hook = function(_) end,
}

-- telescope options when searching sessions
M.telescope_opts = {
	prompt_title = "Sessions",
	cwd = M.opts.session_dir,
	previewer = false,
	layout_strategy = "vertical",
	layout_config = {
		width = 0.5,
	},
}

function M.save_session()
	if not utils.should_save(M.opts) then
		return
	end

	utils.cleanup_buffers(M.opts)

	-- create session directory if it doesn't exist
	if vim.fn.isdirectory(M.opts.session_dir) == 0 then
		vim.fn.mkdir(M.opts.session_dir, "p")
	end

	vim.api.nvim_command("mksession! " .. JudgeState.session_path)
end

function M.load_session(session_name)
	if not utils.should_load(M.opts) then
		return
	end

	M.opts.pre_load_hook()

	vim.api.nvim_command("silent source " .. utils.update_session_state(JudgeState, {
		session_name = session_name,
		session_dir = M.opts.session_dir,
	}).session_path)

	M.opts.post_load_hook(JudgeState)
end

function M.delete_session(session_name)
	session_name = session_name or JudgeState.session_name

	local session_path = utils.build_session_path({
		session_dir = M.opts.session_dir,
		session_name = session_name,
	})

	if vim.fn.filereadable(session_path) == 1 then
		vim.fn.delete(session_path)
	end
end

function M.search_switch_sessions()
	-- open session when selected
	local function on_select(prompt_bufnr, _)
		M.save_session()

		local session_name = require("telescope.actions.state").get_selected_entry(prompt_bufnr).value

		require("telescope.actions").close(prompt_bufnr)

		M.load_session(session_name)
	end

	local function on_delete(prompt_bufnr, _)
		require("telescope.actions.state").get_current_picker(prompt_bufnr):delete_selection(function(selection)
			M.delete_session(selection.value)
		end)
	end

	-- copy telescope options
	local opts = vim.tbl_deep_extend("force", {}, M.telescope_opts)

	-- attach custom mappings
	opts.attach_mappings = function(_, map)
		map("i", "<CR>", on_select)
		map("n", "<CR>", on_select)
		map("i", "<C-d>", on_delete)
		map("n", "<C-d>", on_delete)
		return true
	end

	require("telescope.builtin").find_files(opts)
end

function M.go_to_previous_session()
	M.load_session(JudgeState.previous_session_name)
end

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	utils.update_session_state(JudgeState, {
		session_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t"),
		session_dir = M.opts.session_dir,
	})

	-- Load session on start
	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			M.load_session(JudgeState.session_name)
		end,
		nested = true,
	})

	-- Write session on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.save_session()
		end,
	})
end

return M
