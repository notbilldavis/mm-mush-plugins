local M = {}

require("serializationhelper")

local WIN = "configuration_" .. GetPluginID()
local FONT = WIN .. "_font"
local FONT_UNDERLINE = WIN .. "_font_underline"

local WINDOW_WIDTH = 225
local WINDOW_HEIGHT = 25
local WINDOW_X = nil
local WINDOW_Y = nil
local LINE_HEIGHT = nil
local LABEL_WIDTH = 100
local VALUE_WIDTH = 100
local BORDER_WIDTH = 3
local WINDOW_INFO = ""
local SECTION_STATUS = { }
local CONFIG = { }
local SAVE_CALLBACK

function M.IsOpen()
  return WindowInfo(WIN, 5)
end

function M.Show(config, saveCallback)
  if not M.IsOpen() then
    CONFIG = config
    SAVE_CALLBACK = saveCallback
    initialize()
  end

  show()
end

function initialize()
  WindowCreate(WIN, 0, 0, 0, 0, miniwin.pos_center_all, 0, 0)
  WindowFont(WIN, FONT, "Lucida Console", 9)
  WindowFont(WIN, FONT_UNDERLINE, "Lucida Console", 9, false, false, true)

  BORDER_WIDTH = GetInfo(277)
  LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1) - WindowFontInfo(WIN, FONT, 4) + 2 
end

function show()
  drawWindow()
  drawHeader()
  drawOptions()  

  WindowSetZOrder(WIN, 9999)
  WindowShow(WIN, true)
end

function drawWindow()
  calculateSizeAndPosition()
  WindowPosition(WIN, WINDOW_X, WINDOW_Y , 4, 2)
  WindowResize(WIN, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  for i = 1, BORDER_WIDTH + 1 do
    WindowRectOp(WIN, miniwin.rect_frame, 0 + i, 0 + i, WINDOW_WIDTH - i, WINDOW_HEIGHT - i, ColourNameToRGB("silver"))
  end
end

function drawHeader()
  WindowText(WIN, FONT, "Configuration", 4 + BORDER_WIDTH, 4 + BORDER_WIDTH, 0, 0, ColourNameToRGB("white"), true)
  WindowLine(WIN, WINDOW_WIDTH - LINE_HEIGHT - 2 - BORDER_WIDTH, 2 + BORDER_WIDTH, WINDOW_WIDTH - 2 - BORDER_WIDTH, LINE_HEIGHT + 2 + BORDER_WIDTH, ColourNameToRGB("white"), miniwin.pen_solid, 2)
  WindowLine(WIN, WINDOW_WIDTH - LINE_HEIGHT - 2 - BORDER_WIDTH, LINE_HEIGHT + 2 + BORDER_WIDTH, WINDOW_WIDTH - 2 - BORDER_WIDTH, 2 + BORDER_WIDTH, ColourNameToRGB("white"), miniwin.pen_solid, 2)
  WindowAddHotspot(WIN, "close_hotspot", WINDOW_WIDTH - LINE_HEIGHT - 2 - BORDER_WIDTH, 2 + BORDER_WIDTH, WINDOW_WIDTH - 2 - BORDER_WIDTH, LINE_HEIGHT + 2 + BORDER_WIDTH, "", "", "", "", "onConfigureCloseClick", "Close", miniwin.cursor_hand, 0)

  local single, space = WindowTextWidth(WIN, FONT, "[+]"), WindowTextWidth(WIN, FONT, " ")
  local start_x = 4 + BORDER_WIDTH + WindowTextWidth(WIN, FONT, "Configuration") + space
  local collapse_color, expand_color = ColourNameToRGB("dimgray"), ColourNameToRGB("dimgray")

  for k, _ in pairs(CONFIG) do
    if SECTION_STATUS[k] then
      collapse_color = ColourNameToRGB("white")
    else
      expand_color = ColourNameToRGB("white")
    end
  end

  WindowText(WIN, FONT, "[+] ", start_x, 6, 0, 0, expand_color)
  WindowText(WIN, FONT, "[-]", start_x + single + space, 6, 0, 0, collapse_color)
  if expand_color == ColourNameToRGB("white") then
    WindowAddHotspot(WIN, "expand_all", start_x, 6, start_x + single, 6 + LINE_HEIGHT, "", "", "", "", "onConfigureExpandCollapseClick", "", miniwin.cursor_hand, 0)
  end
  if collapse_color == ColourNameToRGB("white") then
    WindowAddHotspot(WIN, "collapse_all", start_x + single + space, 6, start_x + space + single * 2, 6 + LINE_HEIGHT, "", "", "", "", "onConfigureExpandCollapseClick", "", miniwin.cursor_hand, 0)
  end
end

function drawOptions()
  local y = LINE_HEIGHT + (BORDER_WIDTH * 2)
  for key, group in pairsByKeys(CONFIG) do
    y = drawSection(0, y, key, group)
  end
end

function drawSection(indents, y, key, group)
  local marker = " - "
  if not SECTION_STATUS[key] then marker = " + " end
  for i = 1, indents do marker = " " .. marker end
  local title = key:match(".+^(.+)$")
  if not title then title = key end
  title = title:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)

  local title_width = WindowTextWidth(WIN, FONT, title)
  WindowText(WIN, FONT, marker .. title, 4 + BORDER_WIDTH, y, 0, 0, ColourNameToRGB("white"), true)
  WindowAddHotspot(WIN, key, BORDER_WIDTH, y, title_width + BORDER_WIDTH + 2, y + LINE_HEIGHT, "", "", "", "", "onConfigureExpandCollapseClick", "", miniwin.cursor_hand, 0)
  y = y + LINE_HEIGHT

  if SECTION_STATUS[key] then
    for k, v in pairsByKeys(group) do
      if v == nil then
        -- do nothin
      elseif v.type == nil then
        y = drawSection(indents + 1, y, key .. "^" .. k, v)
      else
        y = drawOption(indents, y, key, k, v)
      end
    end
  end

  return y
end

function drawOption(indents, y, parent_key, key, option)
  if option == nil then
    return y
  end

  if option.label == nil then option.label = key:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end

  local marker = "  * "
  for i = 1, indents do marker = " " .. marker end

  WindowText(WIN, FONT, marker .. option.label, 2 + BORDER_WIDTH, y, 0, 0, ColourNameToRGB("white"), true)
  if option.type == "color" then
    WindowRectOp(WIN, miniwin.rect_fill, LABEL_WIDTH + 20 + BORDER_WIDTH, y + 1, WINDOW_WIDTH - 5 - BORDER_WIDTH, y + LINE_HEIGHT - 1, option.raw_value)
    WindowRectOp(WIN, miniwin.rect_frame, LABEL_WIDTH + 20 + BORDER_WIDTH, y + 1, WINDOW_WIDTH - 5 - BORDER_WIDTH, y + LINE_HEIGHT - 1, ColourNameToRGB("white"))
    WindowAddHotspot(WIN, parent_key .. "|" .. key, LABEL_WIDTH + 20 + BORDER_WIDTH, y + 1, WINDOW_WIDTH - 5 - BORDER_WIDTH, y + LINE_HEIGHT - 1, "", "", "", "", "onConfigureChangeClick", "click to change", miniwin.cursor_hand, 0)
  elseif option.type == "number" then
    if option.value == nil then option.value = tostring(option.raw_value) end
    local b_width = WindowTextWidth(WIN, FONT, "-")
    local v_width = WindowTextWidth(WIN, FONT, option.value)
    local minus_color = ColourNameToRGB("white")
    local add_color = ColourNameToRGB("white")
    if option.raw_value == nil then tonumber(option.value or 0) end
    if option.min ~= nil and option.raw_value <= option.min then minus_color = ColourNameToRGB("dimgray") end
    if option.max ~= nil and option.raw_value >= option.max then add_color = ColourNameToRGB("dimgray") end
    WindowText(WIN, FONT, "-", LABEL_WIDTH + 20 + BORDER_WIDTH, y, 0, 0, minus_color, true)
    WindowText(WIN, FONT_UNDERLINE, tostring(option.value), LABEL_WIDTH + 20 + BORDER_WIDTH + b_width * 2, y, 0, 0, ColourNameToRGB("white"), true)
    WindowText(WIN, FONT, "+", LABEL_WIDTH + 20 + BORDER_WIDTH + v_width + b_width * 3, y, 0, 0, ColourNameToRGB("white"), true)
    WindowAddHotspot(WIN, parent_key .. "|" .. key .. "|minus", LABEL_WIDTH + 20 + BORDER_WIDTH, y+1, LABEL_WIDTH + 20 + BORDER_WIDTH + b_width, y + LINE_HEIGHT - 1, "", "", "", "", "onConfigureChangeClick", "click to decrease", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, parent_key .. "|" .. key, LABEL_WIDTH + 20 + BORDER_WIDTH + b_width * 2, y+1, LABEL_WIDTH + 20 + BORDER_WIDTH + v_width + b_width * 2, y + LINE_HEIGHT - 1, "", "", "", "", "onConfigureChangeClick", "click to change", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, parent_key .. "|" .. key .. "|add", LABEL_WIDTH + 20 + BORDER_WIDTH + v_width + b_width * 3, y+1, LABEL_WIDTH + 20 + BORDER_WIDTH + v_width + b_width * 4, y + LINE_HEIGHT - 1, "", "", "", "", "onConfigureChangeClick", "click to increase", miniwin.cursor_hand, 0)
  else
    if option.value == nil then option.value = tostring(option.raw_value) end
    local v_width = WindowTextWidth(WIN, FONT, option.value)
    WindowText(WIN, FONT_UNDERLINE, tostring(option.value), LABEL_WIDTH + 20 + BORDER_WIDTH, y, 0, 0, ColourNameToRGB("white"), true)
    WindowAddHotspot(WIN, parent_key .. "|" .. key, LABEL_WIDTH + 20 + BORDER_WIDTH, y+1, LABEL_WIDTH + 20 + BORDER_WIDTH + v_width, y + LINE_HEIGHT - 1, "", "", "", "", "onConfigureChangeClick", "click to change", miniwin.cursor_hand, 0)
  end

  return y + LINE_HEIGHT
end

function M.Hide()
  WindowShow(WIN, false)
end

function onConfigureCloseClick(flags, hotspot_id)
  WindowShow(WIN, false)
end

function onConfigureChangeClick(flags, hotspot_id)
  local ids = utils.split(hotspot_id, "|")
  local group_id, option_id = ids[1], ids[2]
  local opt_mode = ids[3]
  local nested_groups = utils.split(group_id, "^")
  local group = CONFIG[nested_groups[1]]

  for i = 2, #nested_groups do
    group = group[nested_groups[i]]
  end

  local option = group[option_id]
  if option.type == "number" then changeNumber(option, opt_mode)
  elseif option.type == "text" then changeText(option)
  elseif option.type == "color" then changeColor(option)
  elseif option.type == "font" then changeFont(option)
  elseif option.type == "bool" then changeBool(option)
  elseif option.type == "list" then changeList(option)
  end

  SAVE_CALLBACK(group_id, option_id, option)
end

function onConfigureExpandCollapseClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if hotspot_id == "expand_all" then
      for sec, _ in pairs(SECTION_STATUS) do
        SECTION_STATUS[sec] = true
      end
    elseif hotspot_id == "collapse_all" then
      for sec, _ in pairs(SECTION_STATUS) do
        SECTION_STATUS[sec] = false
      end
    else
      SECTION_STATUS[hotspot_id] = not SECTION_STATUS[hotspot_id]
    end
    show()
  end
end

function changeNumber(option, opt_mode)
  if opt_mode ~= nil then
    local current = option.raw_value
    if opt_mode == "minus" then    
      option.value = tostring(current - 1)
      option.raw_value = current - 1
    elseif opt_mode == "add" then
      option.value = tostring(current + 1)
      option.raw_value = current + 1
    end
  else
    local min, max = option.min, option.max
    local message = "Choose a new number"
    if min ~= nil and max ~= nil then
      message = message .. " (" .. min .. " to " .. max .. ")"
    end
    local user_input = tonumber(utils.inputbox(
      message, 
      option.label, 
      option.raw_value, nil, nil,
      { 
        validate = validateNumber(min, max),
        prompt_height = 14,
        box_height = 130,
        box_width = 300,
        reply_width = 150,
        max_length = 4,
      }))

    if user_input ~= nil then
      option.value = tostring(user_input)
      option.raw_value = user_input
    end
  end
  show()
end

function changeText(option)
  local message = "Choose a new value"
  local user_input = utils.inputbox(
    message, 
    option.label, 
    option.raw_value, nil, nil,
    { 
      prompt_height = 14,
      box_height = 130,
      box_width = 300,
      reply_width = 150,
    })

  if user_input ~= nil then
    option.value = user_input
    option.raw_value = user_input
  end
  show()
end

function changeColor(option)
  local new_color = PickColour(option.raw_value)
  if new_color >= 0 then
    option.value = new_color
    option.raw_value = new_color
  end
  show()
end

function changeFont(option)
  local new_font = utils.fontpicker(option.raw_value.name, option.raw_value.size, option.raw_value.colour)

  if new_font ~= nil then
    option.value = new_font.name
    option.raw_value = new_font
  end
  show()
end

function changeBool(option)
  option.raw_value = not option.raw_value
  if option.raw_value then
    option.value = "true"
  else
    option.value = "false"
  end
  show()
end

function changeList(option)
  local message = "Choose a new value"
  local user_input = utils.choose(
    message, 
    option.label, 
    option.list)

  if user_input ~= nil then
    option.value = tostring(user_input)
    option.raw_value = user_input
  end
  show()
end

function validateNumber(min, max)
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

function pairsByKeys(t)
  local a = {}
  for key, value in pairs(t) do
    table.insert(a, {key = key, value = value})
  end  

  table.sort(a, function(a, b)
    local sort_a = a.value.sort or a.value.label or a.key or ""
    local sort_b = b.value.sort or b.value.label or b.key or ""
    return sort_a < sort_b
  end)

  local i = 0
  local iter = function()
    i = i + 1
    if a[i] == nil then return nil
    else return a[i].key, a[i].value
    end
  end

  return iter
end

function calculateSizeAndPosition()
  local height = 4 + BORDER_WIDTH + LINE_HEIGHT
  local l_width, v_width = 0, 0
  for key, group in pairsByKeys(CONFIG) do
    height, l_width, v_width = measureSection(0, height, key, group, l_width, v_width)
  end
  
  LABEL_WIDTH = math.max(LABEL_WIDTH, l_width)
  VALUE_WIDTH = math.max(VALUE_WIDTH, v_width + WindowTextWidth(WIN, FONT, "- + "))
  WINDOW_HEIGHT = height + BORDER_WIDTH
  WINDOW_WIDTH = LABEL_WIDTH + 25 + VALUE_WIDTH + (BORDER_WIDTH * 2)
  WINDOW_X = ((GetInfo(292) - GetInfo(290)) / 2 + GetInfo(290)) - WINDOW_WIDTH / 2
  WINDOW_Y = ((GetInfo(293) - GetInfo(291)) / 2 + GetInfo(291)) - WINDOW_HEIGHT / 2
end

function measureSection(indents, height, key, group, l_width, v_width)
  height = height + LINE_HEIGHT
  if SECTION_STATUS[key] == nil then
    if string.find(key, "%^") == nil then 
      SECTION_STATUS[key] = true
    else
      SECTION_STATUS[key] = false
    end
  end
  if SECTION_STATUS[key] then
    for k, v in pairsByKeys(group) do
      if v == nil then
        -- do nothin
      elseif v.type == nil then
        height, l_width, v_width = measureSection(indents + 1, height, key .. "^" .. k, v, l_width, v_width)
      else
        height, l_width, v_width = measureOption(indents, height, key, k, v, l_width, v_width)
      end
    end
  end
  return height, l_width, v_width
end

function measureOption(indents, height, parent_key, key, option, l_width, v_width)
  if option == nil then return height, l_width, v_width end
  if option.label == nil then option.label = key:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end
  if option.value == nil then option.value = tostring(option.raw_value) end
  local marker = "  * "
  for i = 1, indents do marker = " " .. marker end
  local label_width = WindowTextWidth(WIN, FONT, marker .. option.label)
  local value_width = WindowTextWidth(WIN, FONT, option.value)
  if label_width > l_width then l_width = label_width end
  if option.type ~= "color" and value_width > v_width then v_width = value_width end
  return height + LINE_HEIGHT, l_width, v_width
end

return M