local M = {}

M.ns = vim.api.nvim_create_namespace("nvim_right_diagnostics")
M.config = {
	spacing_ratio = 0.2, -- fraction of window reserved for spacing
	padding_right = 1, -- right padding

	highlights = {}
}

-- Get width of the signcolumn / status column
local function compute_statuscol_width(win)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local w = 0
	local number = vim.wo.number or vim.wo.relativenumber
	if number then
		w = w + math.ceil(math.log(1 + line, 10))
	end

	if vim.wo.foldcolumn == "auto" then
		w = w + 2 -- approximation: TODO: Can use auto(:%d)?
	else
		local width = string.match(vim.wo.foldcolumn, "%d")
		w = w + width and width or 0
	end

	local sc = vim.wo.signcolumn
	if sc == "yes" then
		w = w + 2
	elseif sc:match("^auto") then
		w = w + 2 -- approximation
	end

	return w
end

-- Setup highlight groups
local function setup_hl()
	if not M.config.highlights.error then
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText1",
			{ fg = vim.api.nvim_get_hl(0, { name = "DiagnosticError", link = false }).fg })
	else
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText1", M.config.highlights.error)
	end
	if not M.config.highlights.warn then
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText2",
			{ fg = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false }).fg })
	else
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText2", M.config.highlights.warn)
	end
	if not M.config.highlights.info then
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText3",
			{ fg = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false }).fg })
	else
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText3", M.config.highlights.info)
	end
	if not M.config.highlights.hint then
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText4",
			{ fg = vim.api.nvim_get_hl(0, { name = "DiagnosticHint", link = false }).fg })
	else
		vim.api.nvim_set_hl(0, "DiagnosticVirtualText4", M.config.highlights.hint)
	end
end


-- Render diagnostics
local function render(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

	local diags = vim.diagnostic.get(bufnr)
	if #diags == 0 then
		return
	end

	local win = vim.api.nvim_get_current_win()
	local win_width = vim.api.nvim_win_get_width(win)
	local status_width = compute_statuscol_width(win)

	local top_line = vim.fn.line("w0")
	local bottom_line = vim.fn.line("w$")

	local used = {}

	for _, d in ipairs(diags) do
		local base_line = d.lnum

		if base_line >= top_line and base_line <= bottom_line and not used[base_line] then
			used[base_line] = true

			local text = d.message:gsub("\n", " ")
			local current_line = base_line
			local remaining = text

			while #remaining > 0 do
				if vim.fn.foldclosed(current_line) ~= -1 then
					break
				end
				if current_line + 1 >= bottom_line  then
					break
				end
				local line_count = vim.api.nvim_buf_line_count(bufnr)
				if current_line < 1 or current_line > line_count then
					break
				end

				-- Line width
				local line_text = vim.api.nvim_buf_get_lines(bufnr, current_line, current_line + 1, false)[1] or ""
				local content_width = #line_text

				local avail = math.floor(
					(win_width - status_width) * (1 - M.config.spacing_ratio) - content_width - M.config.padding_right
				)
				if avail < 1 then avail = 1 end

				-- Next chunk
				local seg = remaining:sub(1, avail)
				remaining = remaining:sub(avail + 1)

				local col = math.max(0, win_width - status_width - #seg)

				-- One extmark per wrapped line, with highlight
				vim.api.nvim_buf_set_extmark(bufnr, M.ns, current_line, 0, {
					virt_text = { { seg, "DiagnosticVirtualText" .. d.severity } },
					virt_text_pos = "overlay",
					virt_text_win_col = col - 1,
					hl_mode = "combine",
				})


				current_line = current_line + 1
			end
		end
	end
end

M.setup = function(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})

	vim.api.nvim_create_autocmd({
		"BufEnter",
		"BufWinEnter",
		"CursorHold",
		"DiagnosticChanged",
		"TextChanged",
		"TextChangedI",
	}, {
		callback = function(args)
			render(args.buf)
		end,
	})
	setup_hl()
end

return M
