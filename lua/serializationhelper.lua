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
  local load_func = loadstring or load
  local func = load_func("return " .. serializedTable)
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
  if res ~= 0 or Trim(value or "") == "" then return nil end
  return deserialize(value)
end

local function getSerializedVariable(variable_name, default_value)
  local serialized_text = GetVariable(variable_name) or ""
  if serialized_text ~= "" then
    return deserialize(serialized_text)
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

local function setOffset(time_str, convert)
  local hour_offset = GetVariable("hour_offset")

  if convert then
    local month_map = {
      Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
      Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
    }

    local input_time = os.time {
      year = 2000 + tonumber(time_str:sub(22, 25)),
      month = month_map[time_str:sub(5, 7)],
      day = tonumber(time_str:sub(9, 10)),
      hour = tonumber(time_str:sub(12, 13)),
      min = tonumber(time_str:sub(15, 16)),
      sec = tonumber(time_str:sub(18, 19)),
    }

    local offset_seconds = os.difftime(input_time, os.time())
    local offset_hours = math.floor(offset_seconds / 3600 + 0.5)

    hour_offset = tonumber(offset_hours)
  else
    time_str = Trim(time_str or "")
    if time_str == "" then
      if hour_offset ~= nil then
        Note("Current hour offset is " .. hour_offset .. " hours.")
      else
        Note("Hour offset is not set.")
      end
      return
    elseif time_str == "reset" then
      DeleteVariable("hour_offset")
      Note("Hour offset has been reset.")
      return
    end
    
    hour_offset = tonumber(time_str) or 0
  end

  SetVariable("hour_offset", hour_offset)
  SaveState()

  return hour_offset
end

return {
  Serialize = serialize,
  Deserialize = deserialize,
  GetValueOrDefault = getValueOrDefault,
  GetGmcpValue = getGmcpValue,
  GetSerializedVariable = getSerializedVariable,
  SaveSerializedVariable = saveSerializedVariable,
  ConvertToBool = convertToBool,
  SetOffset = setOffset,
}