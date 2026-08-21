local sandbox = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

dofile(sandbox .. "/lazy.lua")({ "mbarneyjr/cfn.nvim", version = "*" })

dofile(sandbox .. "/common.lua")
