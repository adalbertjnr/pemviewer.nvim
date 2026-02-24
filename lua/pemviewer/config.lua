local M = {}

---@class PemviewerHandler
---@field cmd string
---@field label string

---@class PemviewerWindowOptions
---@field relativenumber? boolean
---@field number? boolean
---@field wrap? boolean

---@class PemviewerWindowConfig
---@field width_ratio number
---@field height_ratio number
---@field border string
---@field win_options? PemviewerWindowOptions

---@class PemviewerConfig
---@field show_summary boolean
---@field handlers table<string, PemviewerHandler>
---@field window PemviewerWindowConfig

---@type PemviewerConfig
M.defaults = {
	show_summary = true,

	handlers = {
		["CERTIFICATE"] = { cmd = "openssl x509 -text -noout", label = "Certificate" },
		["CERTIFICATE REQUEST"] = { cmd = "openssl req -text -noout", label = "Certificate Signing Request" },
		["RSA PRIVATE KEY"] = { cmd = "openssl rsa -text -noout", label = "RSA Private Key" },
		["EC PRIVATE KEY"] = { cmd = "openssl ec -text -noout", label = "EC Private Key" },
		["PRIVATE KEY"] = { cmd = "openssl pkey -text -noout", label = "PKCS8 Private Key" },
		["ENCRYPTED PRIVATE KEY"] = { cmd = "openssl pkey -text -noout", label = "Encrypted Private Key" },
		["TRUSTED CERTIFICATE"] = { cmd = "openssl x509 -text -noout", label = "Trusted Certificate" },
	},

	window = {
		width_ratio = 0.3,
		height_ratio = 0.8,
		border = "rounded",

		win_options = {
			relativenumber = true,
			-- ...
		},
	},
}

---@type PemviewerConfig
M.opts = vim.deepcopy(M.defaults)

---@param opts? table
---return PemviewerConfig
function M.setup(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.defaults, opts)
	return M.opts
end

---@return table<string, PemviewerHandler>
function M.get_handlers()
	return vim.tbl_extend("force", M.defaults.handlers, M.opts.handlers or {})
end

return M
