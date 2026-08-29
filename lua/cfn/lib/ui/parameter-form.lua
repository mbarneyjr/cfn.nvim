local M = {}

local state = require("cfn.lib.state")
local credentials = require("cfn.lib.credentials")
local notify = require("cfn.lib.notify")
local lsp = require("cfn.lib.lsp")

local ns = vim.api.nvim_create_namespace("cfn_param_form")
---@type integer?
local bufnr
---@type integer?
local winid
---@type boolean
local submitted = false
---@type boolean
local rendering = false
---@type boolean
local reconcile_scheduled = false

local CFN_PARAMETER_TYPE_MAP = {
  ["AWS::EC2::Instance::Id"] = "AWS::EC2::Instance",
  ["AWS::EC2::KeyPair::KeyName"] = "AWS::EC2::KeyPair",
  ["AWS::EC2::SecurityGroup::Id"] = "AWS::EC2::SecurityGroup",
  ["AWS::EC2::Subnet::Id"] = "AWS::EC2::Subnet",
  ["AWS::EC2::VPC::Id"] = "AWS::EC2::VPC",
  ["AWS::EC2::Volume::Id"] = "AWS::EC2::Volume",
  ["AWS::Route53::HostedZone::Id"] = "AWS::Route53::HostedZone",
  ["AWS::SSM::Parameter::Name"] = "AWS::SSM::Parameter",
}

local function window_is_open()
  return winid ~= nil and vim.api.nvim_win_is_valid(winid) and bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
end

---@param param CfnLspTemplateParameter
local function value_of(param)
  return param.CurrentValue or tostring(param.Default or "")
end

---@param values CfnLspParameterValue[]
---@return string[]
local function allowed_value_strings(values)
  return vim.tbl_map(tostring, values)
end

---@return boolean
local function matches_pattern(value, pattern)
  local ok, re = pcall(vim.regex, "\\v^(" .. pattern .. ")$")
  if not ok then
    return true
  end
  return re:match_str(value) ~= nil
end

---@param param CfnLspTemplateParameter
local function validate_param(param)
  if param.Type == "Number" and not tonumber(value_of(param)) then
    return false, "value not a number"
  elseif param.Type == "List<Number>" then
    for _, v in ipairs(vim.split(value_of(param), ",")) do
      if not tonumber(v) then
        return false, "value not a list of numbers"
      end
    end
  elseif param.AllowedPattern ~= nil and not matches_pattern(value_of(param), param.AllowedPattern) then
    return false, "value does not match AllowedPattern"
  elseif
    param.AllowedValues ~= nil and not vim.tbl_contains(allowed_value_strings(param.AllowedValues), value_of(param))
  then
    return false, "value not one of AllowedValues"
  elseif param.MaxLength and param.CurrentValue and (#param.CurrentValue > param.MaxLength) then
    return false, "value exceeds MaxLength"
  elseif param.MinLength and param.CurrentValue and (#param.CurrentValue < param.MinLength) then
    return false, "value below MinLength"
  elseif (param.MaxValue or param.MinValue) and param.CurrentValue then
    local number = tonumber(param.CurrentValue)
    if number == nil then
      return false, "value not a number"
    elseif param.MaxValue and number > param.MaxValue then
      return false, "value exceeds MaxValue"
    elseif param.MinValue and number < param.MinValue then
      return false, "value below MinValue"
    end
  end
  return true
end

---@param params CfnLspTemplateParameter[]
local function render_decorations(params)
  local max_length = 0
  for _, param in ipairs(params) do
    max_length = math.max(max_length, #param.name)
  end
  vim.api.nvim_buf_clear_namespace(assert(bufnr), ns, 0, -1)
  vim.api.nvim_buf_set_extmark(assert(bufnr), ns, 0, 0, {
    virt_text = { { string.format("%" .. max_length .. "s", "Name"), "Label" } },
    virt_text_pos = "inline",
    right_gravity = false,
    undo_restore = false,
  })
  vim.api.nvim_buf_set_extmark(assert(bufnr), ns, 0, 0, {
    virt_text = { { "UsePreviousValue", "Question" } },
    virt_text_pos = "eol_right_align",
    right_gravity = true,
    undo_restore = false,
  })
  for i, param in ipairs(params) do
    vim.api.nvim_buf_set_extmark(assert(bufnr), ns, i, 0, {
      virt_text = { { param.Type, "Comment" } },
      virt_text_pos = "eol",
      undo_restore = false,
    })
    vim.api.nvim_buf_set_extmark(assert(bufnr), ns, i, 0, {
      virt_text = { { string.format("%" .. max_length .. "s", param.name) .. ": ", "Label" } },
      virt_text_pos = "inline",
      right_gravity = false,
      undo_restore = false,
    })
    vim.api.nvim_buf_set_extmark(assert(bufnr), ns, i, 0, {
      virt_text = { { param.UsePreviousValue and "[x]" or "[ ]", "Question" } },
      virt_text_pos = "eol_right_align",
      right_gravity = true,
      undo_restore = false,
    })
    local valid, err_msg = validate_param(param)
    if not valid then
      vim.api.nvim_buf_set_extmark(assert(bufnr), ns, i, 0, {
        virt_lines = {
          { { string.rep(" ", max_length + 2) .. (param.ConstraintDescription or err_msg), "DiagnosticError" } },
        },
        undo_restore = false,
      })
    end
  end
end

---@param params CfnLspTemplateParameter[]
local function render(params)
  if not window_is_open() then
    return
  end
  rendering = true
  local lines = {
    "",
  }
  for i, param in ipairs(params) do
    lines[i + 1] = value_of(param)
  end
  pcall(vim.cmd.undojoin)
  pcall(vim.api.nvim_buf_set_lines, assert(bufnr), 0, -1, false, lines)
  pcall(render_decorations, params)
  rendering = false
end

---@param params CfnLspTemplateParameter[]
local function valid_window_state(params)
  if not window_is_open() then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(assert(bufnr), 0, 1, false)
  if lines[1] ~= "" then
    return false
  end
  if (vim.api.nvim_buf_line_count(assert(bufnr)) - 1) ~= #params then
    return false
  end
  return true
end

---@param params CfnLspTemplateParameter[]
local function reconcile(params)
  reconcile_scheduled = false
  if not window_is_open() then
    return
  end
  if not valid_window_state(params) then
    render(params)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(assert(bufnr), 1, -1, false)
  for i, param in ipairs(params) do
    local new_value = lines[i] or ""
    if new_value ~= param.CurrentValue then
      param.CurrentValue = new_value
      param.UsePreviousValue = false
    end
  end
  render_decorations(params)
end

---@param params CfnLspTemplateParameter[]
---@param template_path string
local function choose_value(params, template_path)
  if not window_is_open() then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(assert(winid))
  local line = cursor[1]
  local param = params[line - 1]
  if not param then
    return
  end
  if param.AllowedValues ~= nil then
    vim.ui.select(allowed_value_strings(param.AllowedValues), {
      prompt = "Choose value for " .. param.name,
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice ~= nil then
        param.CurrentValue = choice
        render(params)
      end
    end)
    return
  end

  local param_type = param.Type
  if param_type ~= nil and param_type:match("^AWS::SSM::Parameter::Value") then
    param_type = "AWS::SSM::Parameter::Name"
  end
  if CFN_PARAMETER_TYPE_MAP[param_type] ~= nil then
    local registration = state.template_registration:get(template_path)
    if registration == nil then
      notify.error("current template is not registered, please run :Cfn template register")
      return
    end
    credentials.set(registration.profile, registration.region)
    local err, resources = lsp.resources.list_resources_all({ { resourceType = CFN_PARAMETER_TYPE_MAP[param_type] } })
    if err ~= nil or resources == nil or #resources == 0 then
      vim.notify("could not list " .. param_type .. " resources: " .. (err or "no resources"), vim.log.levels.ERROR)
      return
    end
    vim.ui.select(resources[1].resourceIdentifiers, {
      prompt = "Choose value for " .. param.name,
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice ~= nil then
        param.CurrentValue = choice
        render(params)
      end
    end)
  end
end

---@param params CfnLspTemplateParameter[]
---@return CfnLspParameter[]?
local function build_parameter_values(params)
  ---@type CfnLspParameter[]
  local result = {}
  for _, param in ipairs(params) do
    if param.UsePreviousValue then
      table.insert(result, {
        ParameterKey = param.name,
        UsePreviousValue = true,
      })
    else
      table.insert(result, {
        ParameterKey = param.name,
        ParameterValue = value_of(param),
      })
    end
  end
  return result
end

---@param params CfnLspTemplateParameter[]
---@param template_path string
---@return string? error
---@return CfnLspParameter[]?
function M.collect_parameter_values(params, template_path)
  local co = assert(coroutine.running(), "collect_parameter_values must be called from a coroutine")
  if #params == 0 then
    return nil, {}
  end
  if window_is_open() then
    vim.api.nvim_set_current_win(assert(winid))
    return "parameter collection already in progress"
  end
  submitted = false
  for _, param in ipairs(params) do
    param.CurrentValue = value_of(param)
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      winid = nil
      bufnr = nil
      local err, values
      if submitted then
        values = build_parameter_values(params)
      else
        err = "parameter input cancelled"
      end
      vim.schedule(function()
        local ok, resume_err = coroutine.resume(co, err, values)
        if not ok then
          notify.error(resume_err)
        end
      end)
    end,
  })
  local cols = vim.o.columns
  local rows = vim.o.lines
  local width = math.min(80, cols - 4)
  local height = math.min(20, rows - 6)
  local row = math.floor((rows - height) / 2)
  local col = math.floor((cols - width) / 2)
  winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    title = "Parameters",
    border = "rounded",
    footer = "q=close U=use-previous C=choose <C-s>=submit",
    footer_pos = "left",
  })
  vim.api.nvim_set_current_win(winid)

  local undolevels = vim.bo[bufnr].undolevels
  vim.bo[bufnr].undolevels = -1
  render(params)
  vim.bo[bufnr].undolevels = undolevels
  vim.api.nvim_win_set_cursor(winid, { 2, 0 })
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if rendering then
        return
      end
      if not reconcile_scheduled then
        reconcile_scheduled = true
        vim.schedule(function()
          reconcile(params)
        end)
      end
    end,
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(winid, true)
  end, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "C", function()
    coroutine.wrap(function()
      choose_value(params, template_path)
    end)()
  end, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-s>", function()
    reconcile(params)
    submitted = true
    vim.api.nvim_win_close(winid, true)
  end, { buffer = bufnr, nowait = true, desc = "submit parameter values" })
  vim.keymap.set("n", "U", function()
    local cursor = vim.api.nvim_win_get_cursor(winid)
    local line = cursor[1]
    if params[line - 1] then
      params[line - 1].UsePreviousValue = not params[line - 1].UsePreviousValue
      render(params)
    end
  end, { buffer = bufnr, nowait = true, desc = "toggle use previous value" })
  return coroutine.yield()
end

return M
