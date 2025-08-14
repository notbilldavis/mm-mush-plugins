local BORDER_WIDTH = GetInfo(277)
local BORDER_OFFSET = GetInfo(276)
local OUTPUT_LEFT = GetInfo(290)
local OUTPUT_TOP = GetInfo(291)
local OUTPUT_RIGHT = GetInfo(292)
local OUTPUT_BOTTOM = GetInfo(293)
local CLIENT_HEIGHT = GetInfo(280)
local CLIENT_WIDTH = GetInfo(281)

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
    Note("offset nil")
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
        SetVariable("hour_offset", hour_offset)
        Note("found offset in " .. p_id)
      else
        break
      end
    end
  end
  
  if hour_offset == nil then
    return nil
  else
    return tonumber(GetVariable("hour_offset"))
  end
end

return {
    border_width = BORDER_WIDTH,
    border_offset = BORDER_OFFSET,
    output_left_inside = OUTPUT_LEFT,
    output_top_inside = OUTPUT_TOP,
    output_right_inside = OUTPUT_RIGHT,
    output_bottom_inside = OUTPUT_BOTTOM,

    output_left_outside = OUTPUT_LEFT - BORDER_OFFSET - BORDER_WIDTH - 1,
    output_top_outside = OUTPUT_TOP - BORDER_OFFSET - BORDER_WIDTH - 1,
    output_right_outside = OUTPUT_RIGHT - BORDER_OFFSET - BORDER_WIDTH + 1,
    output_bottom_outside = OUTPUT_BOTTOM - BORDER_OFFSET - BORDER_WIDTH + 1,

    output_height = OUTPUT_BOTTOM - OUTPUT_TOP,
    output_width = OUTPUT_RIGHT - OUTPUT_LEFT,

    max_height = CLIENT_HEIGHT,
    max_width = CLIENT_WIDTH,

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