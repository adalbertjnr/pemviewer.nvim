local M = {}
local config = require("pemviewer.config")

---@class PemviewerWindow
---@field buf integer
---@field win integer

---@class PEMBlock
---@field type string
---@field raw string

---@type table<integer, PemviewerWindow>
local state = {}

---@param opts { win:integer, buf:integer, width?: integer, height?: integer}
---@return PemviewerWindow
local function render_window(opts)
	local parent_win = opts.win
	local win_opts = config.opts.window

	local win_width = vim.api.nvim_win_get_width(parent_win)
	local win_height = vim.api.nvim_win_get_height(parent_win)

	local width = opts.width or math.floor(vim.o.columns * win_opts.width_ratio)
	local height = opts.height or math.floor(vim.o.lines * win_opts.height_ratio)

	local col = math.floor((win_width - width) / 2)
	local row = math.floor((win_height - height) / 2)

	local win_config = {
		relative = "win",
		win = parent_win,
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = win_opts.border,
	}

	local float_win = vim.api.nvim_open_win(opts.buf, true, win_config)

	for option, value in pairs(win_opts.win_options or {}) do
		vim.api.nvim_set_option_value(option, value, { win = float_win })
	end

	return { buf = opts.buf, win = float_win }
end

---@param content  string
---@return PEMBlock[]
local function extract_pem_blocks(content)
	local blocks = {}

	for block_type, body in content:gmatch("-----BEGIN%s+([^-]+)%-%-%-%-%-(.-)-----END%s+%1%-%-%-%-%-") do
		local full_block = "-----BEGIN " .. block_type .. "-----" .. body .. "-----END " .. block_type .. "-----"

		table.insert(blocks, {
			type = block_type,
			raw = full_block,
		})
	end

	return blocks
end

---@param block PEMBlock
---@return string[]
local function inspect_block(block)
	local handler = config.get_handlers()[block.type]

	if not handler then
		return {
			"Unsupported PEM type: " .. block.type,
			"",
		}
	end

	local cmd = handler.cmd
	local output = vim.fn.systemlist(cmd, block.raw)

	local result = {}

	if #output == 0 then
		table.insert(result, "OpenSSL returned no output.")
	else
		for _, line in ipairs(output) do
			table.insert(result, line)
		end
	end

	table.insert(result, "")
	return result
end

---@return string[]
local function build_error_message()
	local lines = {
		"Not a recognized PEM file",
		"",
		"Supported types:",
	}

	for _, v in pairs(config.get_handlers()) do
		table.insert(lines, "  - " .. v.label)
	end

	return lines
end

---@param content string
---@return string[]
local function generate_output(content)
	local blocks = extract_pem_blocks(content)
	if #blocks == 0 then
		return build_error_message()
	end

	local final_output = {}

	for _, block in ipairs(blocks) do
		local result = inspect_block(block)

		for _, line in ipairs(result) do
			table.insert(final_output, line)
		end
	end

	return final_output
end

---@return nil
local function run()
	local current_win = vim.api.nvim_get_current_win()

	for _, floating in pairs(state) do
		if floating.win and vim.api.nvim_win_is_valid(floating.win) then
			if current_win == floating.win then
				vim.api.nvim_win_hide(floating.win)
				floating.win = nil
				return
			end
		end
	end

	local parent_win = current_win
	state[parent_win] = state[parent_win] or {}
	local floating = state[parent_win]

	if floating.win and vim.api.nvim_win_is_valid(floating.win) then
		vim.api.nvim_set_current_win(floating.win)
		return
	end

	if not (floating.buf and vim.api.nvim_buf_is_valid(floating.buf)) then
		local new_buf = vim.api.nvim_create_buf(false, true)
		floating.buf = new_buf
	end

	local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	local cmd_out = generate_output(content)

	vim.api.nvim_buf_set_lines(floating.buf, 0, -1, false, cmd_out)

	floating = render_window({
		win = parent_win,
		buf = floating.buf,
	})

	state[parent_win] = floating

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(parent_win),
		once = true,
		callback = function()
			if floating.win and vim.api.nvim_win_is_valid(floating.win) then
				vim.api.nvim_win_close(floating.win, true)
			end
			state[parent_win] = nil
		end,
	})
end

---@param opts? table
function M.setup(opts)
	local merged_opts = config.setup(opts)
	M.opts = merged_opts

	vim.api.nvim_create_user_command("PKIInspect", run, {})
end

return M
