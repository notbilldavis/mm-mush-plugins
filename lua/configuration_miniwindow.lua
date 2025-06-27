local CMW = {}
local cmw = {}

local WIN = "configuration_" .. GetPluginID()
local FONT = WIN .. "_font"
local FONT_UNDERLINE = WIN .. "_font_underline"

local WINDOW_WIDTH = 225
local WINDOW_HEIGHT = 25
local LINE_HEIGHT = nil
local LABEL_WIDTH = 100
local VALUE_WIDTH = 100
local WINDOW_INFO = ""
local CONFIG = { }
local SAVE_CALLBACK

-- CONFIG = { WINDOW_WIDTH = { name = "Width", type = "number", value = 150 } }
-- number, text, color, font, toggle, list

function CMW.Show(config, saveCallback)
  CONFIG = config
  SAVE_CALLBACK = saveCallback
  cmw.show()
end

function cmw.show()
  WindowCreate(WIN, 0, 0, 0, 0, miniwin.pos_center_all, 0, 0)
  WindowFont(WIN, FONT, "Lucida Console", 9)
  WindowFont(WIN, FONT_UNDERLINE, "Lucida Console", 9, false, false, true)
  LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1) - WindowFontInfo(WIN, FONT, 4) + 2
  WINDOW_HEIGHT = cmw.getHeight(CONFIG)
  WINDOW_WIDTH = LABEL_WIDTH + 25 + VALUE_WIDTH

  local output_width = GetInfo(292) - GetInfo(290)
  local output_height = GetInfo(293) - GetInfo(291)
  local output_center_x = output_width / 2 + GetInfo(290)
  local output_center_y = output_height / 2 + GetInfo(291)

  WindowPosition(WIN, output_center_x - WINDOW_WIDTH / 2, output_center_y - WINDOW_HEIGHT / 2, 4, 2)
  WindowResize(WIN, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_frame, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("silver"))

  WindowText(WIN, FONT, "Configuration", 4, 2, 0, 0, ColourNameToRGB("white"), true)
  WindowLine(WIN, WINDOW_WIDTH - LINE_HEIGHT - 2, 2, WINDOW_WIDTH - 2, LINE_HEIGHT + 2, ColourNameToRGB("white"), miniwin.pen_solid, 2)
  WindowLine(WIN, WINDOW_WIDTH - LINE_HEIGHT - 2, LINE_HEIGHT + 2, WINDOW_WIDTH - 2, 2, ColourNameToRGB("white"), miniwin.pen_solid, 2)
  WindowAddHotspot(WIN, "close_hotspot", WINDOW_WIDTH - LINE_HEIGHT - 2, 2, WINDOW_WIDTH - 2, LINE_HEIGHT + 2, "", "", "", "", "cmw_configure_close", "Close", miniwin.cursor_hand, 0)
  
  local y = LINE_HEIGHT + 5
  for key, group in cmw.pairsByKeys(CONFIG) do
    if #CONFIG > 1 then WindowText(WIN, FONT, " - " .. key:gsub("_", " ") .. " - ", 2, y, 0, 0, ColourNameToRGB("white"), true) end
    y = y + LINE_HEIGHT
    for k, v in cmw.pairsByKeys(group) do
      if v.label == nil then v.label = k:lower()k:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end
      WindowText(WIN, FONT, "  * " .. v.label, 2, y, 0, 0, ColourNameToRGB("white"), true)
      if v.type == "color" then
        WindowRectOp(WIN, miniwin.rect_fill, LABEL_WIDTH + 20, y + 1, WINDOW_WIDTH - 5, y + LINE_HEIGHT - 1, v.raw_value)
        WindowRectOp(WIN, miniwin.rect_frame, LABEL_WIDTH + 20, y + 1, WINDOW_WIDTH - 5, y + LINE_HEIGHT - 1, ColourNameToRGB("white"))
      else
        if v.value == nil then v.value = tostring(v.raw_value) end
        WindowText(WIN, FONT_UNDERLINE, tostring(v.value), LABEL_WIDTH + 20, y, 0, 0, ColourNameToRGB("white"), true)
      end
      WindowAddHotspot(WIN, key .. "|" .. k, LABEL_WIDTH + 20, y+1, WINDOW_WIDTH - 5, y + LINE_HEIGHT - 1, "", "", "", "", "cmw_configure_change", "click to change", miniwin.cursor_hand, 0)
      
      y = y + LINE_HEIGHT
    end
  end

  WindowSetZOrder(WIN, 9999)
  WindowShow(WIN, true)
end

function CMW.Hide()
  WindowShow(WIN, false)
end

function cmw_configure_close(flags, hotspot_id)
  WindowShow(WIN, false)
end

function cmw_configure_change(flags, hotspot_id)
  local ids = utils.split(hotspot_id, "|")
  local group_id, option_id = ids[1], ids[2]

  if CONFIG[group_id][option_id].type == "number" then cmw.changenumber(flags, group_id, option_id)
  elseif CONFIG[group_id][option_id].type == "text" then cmw.changetext(flags, group_id, option_id)
  elseif CONFIG[group_id][option_id].type == "color" then cmw.changecolor(flags, group_id, option_id)
  elseif CONFIG[group_id][option_id].type == "font" then cmw.changefont(flags, group_id, option_id)
  elseif CONFIG[group_id][option_id].type == "bool" then cmw.changebool(flags, group_id, option_id)
  elseif CONFIG[group_id][option_id].type == "list" then cmw.changelist(flags, group_id, option_id)
  end

  SAVE_CALLBACK(group_id, option_id, CONFIG[group_id][option_id])
end

function cmw.changenumber(flags, group_id, option_id)
  local min, max = CONFIG[group_id][option_id].min, CONFIG[group_id][option_id].max
  local message = "Choose a new number"
  if min ~= nil and max ~= nil then
    message = message .. " (" .. min .. " to " .. max .. ")"
  end
  local user_input = tonumber(utils.inputbox(
    message, 
    CONFIG[group_id][option_id].label, 
    CONFIG[group_id][option_id].raw_value, nil, nil,
    { 
      validate = cmw.validateNumber(min, max),
      prompt_height = 14,
      box_height = 130,
      box_width = 300,
      reply_width = 150,
      max_length = 4,
    }))

  if user_input ~= nil then
    CONFIG[group_id][option_id].value = tostring(user_input)
    CONFIG[group_id][option_id].raw_value = user_input
  end
  cmw.show()
end

function cmw.changetext(flags, group_id, option_id)
  local message = "Choose a new value"
  local user_input = utils.inputbox(
    message, 
    CONFIG[group_id][option_id].label, 
    CONFIG[group_id][option_id].raw_value, nil, nil,
    { 
      prompt_height = 14,
      box_height = 130,
      box_width = 300,
      reply_width = 150,
    })

  if user_input ~= nil then
    CONFIG[group_id][option_id].value = user_input
    CONFIG[group_id][option_id].raw_value = user_input
  end
  cmw.show()
end

function cmw.changecolor(flags, group_id, option_id)
  local new_color = PickColour(CONFIG[group_id][option_id].raw_value)
  if new_color >= 0 then
    CONFIG[group_id][option_id].value = new_color
    CONFIG[group_id][option_id].raw_value = new_color
  end
  cmw.show()
end

function cmw.changefont(flags, group_id, option_id)
  local new_font = utils.fontpicker(CONFIG[group_id][option_id].raw_value.name, CONFIG[group_id][option_id].raw_value.size, CONFIG[group_id][option_id].raw_value.colour)

  if new_font ~= nil then
    CONFIG[group_id][option_id].value = new_font.name
    CONFIG[group_id][option_id].raw_value = new_font
  end
  cmw.show()
end

function cmw.changebool(flags, group_id, option_id)
  CONFIG[group_id][option_id].raw_value = not CONFIG[group_id][option_id].raw_value
  if CONFIG[group_id][option_id].raw_value then
    CONFIG[group_id][option_id].value = "true"
  else
    CONFIG[group_id][option_id].value = "false"
  end
  cmw.show()
end

function cmw.changelist(flags, group_id, option_id)
  local message = "Choose a new value"
  local user_input = utils.choose(
    message, 
    CONFIG[group_id][option_id].label, 
    CONFIG[group_id][option_id].list)

  if user_input ~= nil then
    CONFIG[group_id][option_id].value = tostring(user_input)
    CONFIG[group_id][option_id].raw_value = user_input
  end
  cmw.show()
end

function cmw.validateNumber(min, max)
  return function(s)
    if min == nil or max == nil then return true end
    local n = tonumber(s)
    if not n then
      utils.msgbox("Enter a valid number", "Invalid", "ok", "!", 1)
      return false
    end
    if n < min or n > max then
      utils.msgbox ("Enter a number between " .. min .. " and " .. max, "Invalid", "ok", "!", 1)
      return false
    end
    return true
  end
end

function cmw.pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0
  local iter = function ()
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function cmw.getHeight(config)
  local height = LINE_HEIGHT + 10
  for key, group in cmw.pairsByKeys(config) do
    height = height + LINE_HEIGHT
    for k, v in cmw.pairsByKeys(group) do
      height = height + LINE_HEIGHT
      if v.label == nil then v.label = k:lower()k:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end
      if v.value == nil then v.value = tostring(v.raw_value) end
      local label_width = WindowTextWidth(WIN, FONT, "  * " .. v.label)
      local value_width = WindowTextWidth(WIN, FONT, v.value or v.raw_value)
      if label_width > LABEL_WIDTH then LABEL_WIDTH = label_width end
      if value_width > VALUE_WIDTH then VALUE_WIDTH = value_width end
    end
  end
  return height
end

function cmw.getSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

return CMW