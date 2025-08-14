local function serialize(table)
  local function serializeValue(value)
    if type(value) == "table" then return serialize(value)
    elseif type(value) == "string" then return string.format("%q", value)
    else return tostring(value) end
  end

  local result = "{"
  for k, v in pairs(table) do
    local key
    if type(k) == "string" and k:match("^%a[%w_]*$") then
      key = k
    else
      key = "[" .. serializeValue(k) .. "]"
    end
    result = result .. key .. "=" .. serializeValue(v) .. ","
  end
  result = result .. "}"
  return result
end

local function deserialize(serializedTable)
  local func = load("return " .. serializedTable)
  if func then return func() end
    return nil  
end

local function getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
end

local function getGmcpValue(gmcp_field)
  local res, value = CallPlugin("f67c4339ed0591a5b010d05b", "gmcpval", gmcp_field)
  return deserialize(value)
end

local function getSerializedVariable(variable_name, default_value, backup_variable)
  local serialized_text = GetVariable(variable_name) or ""
  if serialized_text ~= "" then
    return deserialize(serialized_text)
  elseif backup_variable ~= nil then
    serialized_text = GetVariable(variable_name) or ""
    if serialized_text ~= "" then
      return deserialize(serialized_text)
    end
  elseif default_value ~= nil then
    return default_value
  else
    return {}
  end
end

local function saveSerializedVariable(variable_name, variable_to_save)
  SetVariable(variable_name, serialize(variable_to_save))
  SaveState()
end

local function convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

return {
  Serialize = serialize,
  Deserialize = deserialize,
  GetValueOrDefault = getValueOrDefault,
  GetGmcpValue = getGmcpValue,
  GetSerializedVariable = getSerializedVariable,
  SaveSerializedVariable = saveSerializedVariable,
  ConvertToBool = convertToBool
}