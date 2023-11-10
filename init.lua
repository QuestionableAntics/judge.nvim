local M = {}


M.opts = {
	-- directories that should not have sessions persisted
	ignored_directories = {},
	-- close all buffers matching this pattern when saving a session
	ignored_buffer_patterns = {},
	-- don't save session if neovim was called with a path to a specific file
	ignore_argv = true,
	-- directory to save sessions in
	session_dir = vim.fn.expand("$HOME/.nvim/sessions"),
	-- how to build the session name
	build_session_name = function()
		return vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
	end,
	-- function to call when switching to a session
	on_session_switch = function()
		-- stop all lsp servers
		vim.lsp.stop_client(vim.lsp.get_active_clients())
	end,
}


-- telescope options when searching sessions
M.telescope_opts = {
	prompt_title = "Sessions",
	cwd = M.opts.session_dir,
	previewer = false,
	layout_strategy = "vertical",
	layout_config = {
		width = 0.5,
	}
}


function M.should_save()
	local cwd = vim.fn.getcwd()

	-- if neovim was called with a path to a specifc file, don't write session
	if M.ignore_argv and vim.fn.argc() > 0 then return false end

	-- if the current directory is in the ignored directories, don't save session
	for _, ignored_directory in ipairs(M.opts.ignored_directories) do
		if cwd == ignored_directory then
			return false
		end
	end

	return true
end


function M.should_load()
	-- if neovim was called with a path to a specifc file, don't write session
	if M.ignore_argv and vim.fn.argc() > 0 then return false end

	return true
end


function M.cleanup_buffers()
	-- get all open buffers
	local buffers = vim.api.nvim_list_bufs()

	-- for all open buffers
	for _, buffer in ipairs(buffers) do
		local buffer_name = vim.fn.expand("#" .. buffer .. ":~")

		-- if the buffer matches an ignored pattern, delete it
		for _, ignored_buffer_pattern in ipairs(M.opts.ignored_buffer_patterns) do
			if string.find(buffer_name, ignored_buffer_pattern) then
				vim.api.nvim_buf_delete(buffer, { force = true })
			end
		end
	end
end


function M.save_session()
	if not M.should_save() then return end

	M.cleanup_buffers()

	-- create session directory if it doesn't exist
	if vim.fn.isdirectory(M.opts.session_dir) == 0 then
		vim.fn.mkdir(M.opts.session_dir, "p")
	end

	vim.cmd("mksession! " .. M.session_file)
end


function M.load_session(session_file)
	if not M.should_load() then return end

	M.previous_session_file = M.session_file

	if session_file ~= nil then
		M.session_file = session_file
	end

	if vim.fn.filereadable(M.session_file) == 1 then
		vim.cmd("source " .. M.session_file)
	end
end


function M.delete_session(session_file)
	local sf = session_file or M.session_file

	if vim.fn.filereadable(sf) == 1 then
		vim.fn.delete(sf)
	end
end


-- Use telescope to search for sessions
function M.search_sessions(on_select)
	-- copy telescope options
	local search_options = {}
	vim.tbl_extend("force", search_options, M.telescope_opts)

	local opts = vim.tbl_extend("force", M.telescope_opts, search_options)

	-- attach custom mappings
	if on_select ~= nil then
		opts.attach_mappings = function(_, map)
			map("i", "<CR>", on_select)
			map("n", "<CR>", on_select)
			return true
		end
	end

	require("telescope.builtin").find_files(opts)
end


function M.search_switch_sessions()
	-- open session when selected
	local function on_select(prompt_bufnr, map)
		M.save_session()

		M.previous_session_file = M.session_file

		local session_file = M.opts.session_dir .. "/" .. require("telescope.actions.state").get_selected_entry(prompt_bufnr).value

		require("telescope.actions").close(prompt_bufnr)

		M.load_session(session_file)
	end

	M.search_sessions(on_select)
end


function M.search_delete_session()
	-- delete session when selected
	local function on_select(prompt_bufnr, map)
		require("telescope.actions.state").get_current_picker(prompt_bufnr):delete_selection(function(selection)
			local session_file = M.opts.session_dir .. "/" .. selection.value

			M.delete_session(session_file)
		end)
	end

	M.search_sessions(on_select)
end


function M.go_to_previous_session()
	if M.previous_session_file ~= M.session_file then
		M.load_session(M.previous_session_file)
	end
end


function M.setup(opts)
	M.opts = vim.tbl_extend("force", M.opts, opts)

	M.session_file = M.opts.session_dir .. "/" .. M.opts.build_session_name() .. ".vim"

	M.previous_session_file = M.session_file

	-- Load session on start
	vim.api.nvim_create_autocmd(
		"VimEnter",
		{
			callback = function() M.load_session(M.session_file) end,
			nested = true,
		}
	)

	-- Write session on exit
	vim.api.nvim_create_autocmd(
		"VimLeavePre",
		{ callback = M.save_session }
	)
end


return M
