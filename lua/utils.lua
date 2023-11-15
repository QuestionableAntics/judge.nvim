local M = {}


function M.should_save(opts)
	local cwd = vim.fn.getcwd()

	-- if neovim was called with a path to a specifc file, don't write session
	if opts.ignore_argv and vim.fn.argc() > 0 then return false end

	-- if the current directory is in the ignored directories, don't save session
	for _, ignored_directory in ipairs(opts.ignored_directories) do
		if cwd == ignored_directory then
			return false
		end
	end

	return true
end


function M.should_load(opts)
	-- if neovim was called with a path to a specifc file, don't write session
	if opts.ignore_argv and vim.fn.argc() > 0 then return false end

	return true
end


function M.clean_buffers(opts)
	if not opts.ignored_buffer_patterns then return end

	-- get all open buffers
	local buffers = vim.api.nvim_list_bufs()

	-- for all open buffers
	for _, buffer in ipairs(buffers) do
		local buffer_name = vim.fn.expand("#" .. buffer .. ":~")

		-- if the buffer matches an ignored pattern, get it's jumplist and look ahead to find a buffer that doesn't match the pattern
		-- if one is found, set the current buffer to that buffer
		for _, ignored_buffer_pattern in ipairs(M.opts.ignored_buffer_patterns) do
			if string.find(buffer_name, ignored_buffer_pattern) then
				local jumplist = vim.fn.getjumplist(buffer)

				for _, jumplist_entry in ipairs(jumplist) do
					local jumplist_entry_name = vim.fn.expand("#" .. jumplist_entry .. ":~")

					if not string.find(jumplist_entry_name, ignored_buffer_pattern) then
						vim.api.nvim_set_current_buf(jumplist_entry)
						break
					end
				end
			end
		end
	end
end


function M.cleanup_buffers(opts)
	if not opts.ignored_buffer_patterns then return end

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


-- Use telescope to search for sessions
function M.search_sessions(on_select, telescope_opts)
	-- copy telescope options
	local opts = vim.tbl_deep_extend("force", {}, telescope_opts)

	-- attach custom mappings
	opts.attach_mappings = function(_, map)
		map("i", "<CR>", on_select)
		map("n", "<CR>", on_select)
		return true
	end

	require("telescope.builtin").find_files(opts)
end


return M
