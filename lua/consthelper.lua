local function getBorderWidth() return GetInfo(277) end
local function getBorderOffset() return GetInfo(276) end
local function getOutputLeft() return GetInfo(290) end
local function getOutputTop() return GetInfo(291) end
local function getOutputRight() return GetInfo(292) end
local function getOutputBottom() return GetInfo(293) end
local function getClientHeight() return GetInfo(280) end
local function getClientWidth() return GetInfo(281) end

local function getOutputHeight() return getOutputBottom() - getOutputTop() end
local function getOutputWidth() return getOutputRight() - getOutputLeft() end

local function getOutputLeftOutside() return getOutputLeft() - getBorderOffset() - getBorderWidth() - 1 end
local function getOutputTopOutside() return getOutputTop() - getBorderOffset() - getBorderWidth() - 1 end
local function getOutputRightOutside() return getOutputRight() + getBorderOffset() + getBorderWidth() + 1 end
local function getOutputBottomOutside() return getOutputBottom() + getBorderOffset() + getBorderWidth() + 1 end

local function getOutputHeightOutside() return getOutputBottomOutside() - getOutputTopOutside() end
local function getOutputWidthOutside() return getOutputRightOutside() - getOutputLeftOutside() end

local function clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

local function pairsByKeys(tbl, sortFunc)
  local a = {}
  for key, value in pairs(tbl) do
    table.insert(a, {key = key, value = value})
  end  

  if sortFunc then
    table.sort(a, sortFunc)
  end

  local i = 0
  local iter = function()
    i = i + 1
    if a[i] == nil then return nil
    else return a[i].key, a[i].value
    end
  end

  return iter
end

local function convertToTime(time_str, hour_offset)
  local month_map = {
      Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
      Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
  }

  if hour_offset == nil then hour_offset = 1 end

  local day = tonumber(time_str:sub(9, 10))
  local hour = tonumber(time_str:sub(12, 13))
  local minute = tonumber(time_str:sub(15, 16))
  local second = tonumber(time_str:sub(18, 19))
  local year = tonumber(time_str:sub(22, 25))

  local month_str = time_str:sub(5, 7)
  local month = month_map[month_str]

  hour = hour + hour_offset;

  local provided_time = os.time {
      year = year + 2000,
      month = month,
      day = day,
      hour = hour,
      min = minute,
      sec = second,
  }

  return provided_time, year, month, day, hour, minute, second
end

local function getFormattedDateTime(year, month, day, hour, minute, second)  
  local ampm = "am"
  if (hour == 24) then hour = 0 end
  if (hour > 11) then ampm = "pm" end
  if (hour == 0) then hour = 12 end 
  if (hour > 12) then hour = hour - 12 end

  local formatMinute = ""
  if (minute < 10) then
    formatMinute = "0"
  end

  return month .. "/" .. day .. "/" .. year .. " " .. hour .. ":" .. formatMinute .. minute .. " " .. ampm
end

local function getTimeDiffInMinutes(input_time)
  local details = "NOW!"
  local differenceInSeconds = input_time - os.time()
  if differenceInSeconds > 0 then
      local diff_minutes = math.floor(differenceInSeconds / 60)
      details = "in " .. diff_minutes .. " minutes"
  end

  return details
end

local function getHourOffset()
  local hour_offset = GetVariable("hour_offset")
  if hour_offset == nil then
    local other_plugins = { 
      bosses_killed = "ffe0696159421d1841e22b03",
      capture_quests = "892911b648d09c18e1ecd4e6",
      curio_sort = "c8b8a228de108e21e43b9baf",
      lootable_tracker = "804c9c1100a17f8052e79118",
      global = ""
    }

    for _, p_id in pairs(other_plugins) do
      if hour_offset == nil and p_id ~= GetPluginID() then
        hour_offset = GetPluginVariable(p_id, "hour_offset")
      elseif hour_offset ~= nil then
        break
      end
    end
  end
  
  if hour_offset == nil then
    return nil
  else
    SetVariable("hour_offset", hour_offset)
    return tonumber(hour_offset)
  end
end

return {
    GetBorderWidth = getBorderWidth,
    GetBorderOffset = getBorderOffset,
    GetOutputLeft = getOutputLeft,
    GetOutputTop = getOutputTop,
    GetOutputRight = getOutputRight,
    GetOutputBottom = getOutputBottom,

    GetOutputLeftOutside = getOutputLeftOutside,
    GetOutputTopOutside = getOutputTopOutside,
    GetOutputRightOutside = getOutputRightOutside,
    GetOutputBottomOutside = getOutputBottomOutside,

    GetOutputHeight = getOutputHeight,
    GetOutputWidth = getOutputWidth,
    GetOutputHeightOutside = getOutputHeightOutside,
    GetOutputWidthOutside = getOutputWidthOutside,

    GetClientHeight = getClientHeight,
    GetClientWidth = getClientWidth,

    border_color = 12632256,
    black = ColourNameToRGB("black"),
    white = ColourNameToRGB("white"),
    silver = ColourNameToRGB("silver"),    
    dimgray = ColourNameToRGB("dimgray"),

    clamp = clamp,
    pairsByKeys = pairsByKeys,
    convertToTime = convertToTime,
    getHourOffset = getHourOffset,
    getTimeDiffInMinutes = getTimeDiffInMinutes,
    getFormattedDateTime = getFormattedDateTime,
}