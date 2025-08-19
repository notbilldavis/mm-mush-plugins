local const_installed, consts = pcall(require, "consthelper")

local WIN = "configuration_" .. GetPluginID()
local FONT = WIN .. "_font"
local FONT_UNDERLINE = FONT .. "_underline"

local POSITION = nil
local SIZES = nil

local CONFIG = nil
local SAVE_CALLBACK = nil
local SECTION_STATUS = { }

local show, hide, update, createFontOption, createNumberOption, createTextOption, createBoolOption, createColorOption, createListOption
local initialize, calculate, draw, drawWindow, drawHeader, drawSection, drawOptions, drawOption,
 changeNumber, changeText, changeColor, changeBool, changeFont, changeList, validateNumber, measureSection,
 measureOption

show = function(config, saveCallback)
  if not CONFIG then
    CONFIG = config
    SAVE_CALLBACK = saveCallback
    initialize()
  end

  draw()
end

update = function(config)
  if WindowInfo(WIN, 5) then
    CONFIG = config
    draw()
  end
end

initialize = function()
  WindowCreate(WIN, 0, 0, 50, 50, miniwin.pos_center_all, 0, 0)
  WindowSetZOrder(WIN, 9999)
  WindowFont(WIN, FONT, "Lucida Console", 9)
  WindowFont(WIN, FONT_UNDERLINE, "Lucida Console", 9, false, false, true)

  POSITION = {}
  SIZES = {}

  SIZES.LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1) - WindowFontInfo(WIN, FONT, 4) + 2 
  SIZES.LABEL_WIDTH = 100
  SIZES.VALUE_WIDTH = 100
end

draw = function()
  WindowShow(WIN, false)

  calculate()
  drawWindow()  
  drawHeader()
  drawOptions()

  WindowShow(WIN, true)
end

drawWindow = function()
  WindowPosition(WIN, POSITION.WINDOW_LEFT, POSITION.WINDOW_TOP , 4, 2)
  WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, consts.black)
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, consts.black)
  for i = 1, consts.GetBorderWidth() + 1 do
    WindowRectOp(WIN, miniwin.rect_frame, 0 + i, 0 + i, POSITION.WINDOW_WIDTH - i, POSITION.WINDOW_HEIGHT - i, consts.silver)
  end
end

drawHeader = function()
  WindowText(WIN, FONT, "Configuration", 4 + consts.GetBorderWidth(), 4 + consts.GetBorderWidth(), 0, 0, consts.white, true)
  WindowLine(WIN, POSITION.WINDOW_WIDTH - SIZES.LINE_HEIGHT - 2 - consts.GetBorderWidth(), 2 + consts.GetBorderWidth(), POSITION.WINDOW_WIDTH - 2 - consts.GetBorderWidth(), SIZES.LINE_HEIGHT + 2 + consts.GetBorderWidth(), consts.white, miniwin.pen_solid, 2)
  WindowLine(WIN, POSITION.WINDOW_WIDTH - SIZES.LINE_HEIGHT - 2 - consts.GetBorderWidth(), SIZES.LINE_HEIGHT + 2 + consts.GetBorderWidth(), POSITION.WINDOW_WIDTH - 2 - consts.GetBorderWidth(), 2 + consts.GetBorderWidth(), consts.white, miniwin.pen_solid, 2)
  WindowAddHotspot(WIN, "close_hotspot", POSITION.WINDOW_WIDTH - SIZES.LINE_HEIGHT - 2 - consts.GetBorderWidth(), 2 + consts.GetBorderWidth(), POSITION.WINDOW_WIDTH - 2 - consts.GetBorderWidth(), SIZES.LINE_HEIGHT + 2 + consts.GetBorderWidth(), "", "", "", "", "configuration_onClose", "Close", miniwin.cursor_hand, 0)

  local single, space = WindowTextWidth(WIN, FONT, "[+]"), WindowTextWidth(WIN, FONT, " ")
  local start_x = 4 + consts.GetBorderWidth() + WindowTextWidth(WIN, FONT, "Configuration") + space
  local collapse_color, expand_color = consts.dimgray, consts.dimgray

  for k, _ in pairs(CONFIG) do
    if SECTION_STATUS[k] then
      collapse_color = consts.white
    else
      expand_color = consts.white
    end
  end

  WindowText(WIN, FONT, "[+] ", start_x, 6, 0, 0, expand_color)
  WindowText(WIN, FONT, "[-]", start_x + single + space, 6, 0, 0, collapse_color)
  if expand_color == consts.white then
    WindowAddHotspot(WIN, "expand_all", start_x, 6, start_x + single, 6 + SIZES.LINE_HEIGHT, "", "", "", "", "configuration_onExpandCollapse", "", miniwin.cursor_hand, 0)
  end
  if collapse_color == consts.white then
    WindowAddHotspot(WIN, "collapse_all", start_x + single + space, 6, start_x + space + single * 2, 6 + SIZES.LINE_HEIGHT, "", "", "", "", "configuration_onExpandCollapse", "", miniwin.cursor_hand, 0)
  end
end

drawOptions = function()
  local y = SIZES.LINE_HEIGHT + (consts.GetBorderWidth() * 2)
  for key, group in consts.pairsByKeys(CONFIG) do
    y = drawSection(0, y, key, group)
  end
end

drawSection = function(indents, y, key, group)
  local marker = " - "
  if not SECTION_STATUS[key] then marker = " + " end
  for i = 1, indents do marker = " " .. marker end
  local title = key:match(".+^(.+)$")
  if not title then title = key end
  title = title:match("^_?%d*_?(.*)$")
  title = title:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)

  local title_width = WindowTextWidth(WIN, FONT, marker .. title)
  WindowText(WIN, FONT, marker .. title, 4 + consts.GetBorderWidth(), y, 0, 0, consts.white, true)
  WindowAddHotspot(WIN, key, consts.GetBorderWidth(), y, title_width + consts.GetBorderWidth() + 2, y + SIZES.LINE_HEIGHT, "", "", "", "", "configuration_onExpandCollapse", "", miniwin.cursor_hand, 0)
  y = y + SIZES.LINE_HEIGHT

  local sortFunc = function(a, b)
    local sort_a = a.value.sort 
    local sort_b = b.value.sort

    if sort_a == nil then
      local sa = a.key:match("_(%d+)_")
      if sa ~= nil then sort_a = tonumber(sa) end
    end

    if sort_b == nil then
      local sb = a.key:match("_(%d+)_")
      if sb ~= nil then sort_b = tonumber(sb) end
    end

    if sort_a == nil and sort_b == nil then
      sort_a = a.value.label or a.key or ""
      sort_b = b.value.label or b.key or ""
    elseif sort_a == nil then
      sort_a = 9999
    elseif sort_b == nil then
      sort_b = 9999
    end

    return sort_a < sort_b
  end

  if SECTION_STATUS[key] then
    for k, v in consts.pairsByKeys(group, sortFunc) do
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

drawOption = function(indents, y, parent_key, key, option)
  if option == nil then
    return y
  end

  if option.label == nil then option.label = key:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end

  local marker = "  * "
  for i = 1, indents do marker = " " .. marker end

  local label_color = consts.white
  if option.enabled == false then
    label_color = consts.dimgray
  end

  WindowText(WIN, FONT, marker .. option.label, 2 + consts.GetBorderWidth(), y, 0, 0, label_color, true)
  if option.hint ~= nil and Trim(option.hint) ~= "" then
    WindowAddHotspot(WIN, "hint_" .. parent_key .. "|" .. key, 2 + consts.GetBorderWidth(), y, 2 + consts.GetBorderWidth() + SIZES.LABEL_WIDTH, y + SIZES.LINE_HEIGHT, "", "", "", "", "", option.hint, miniwin.cursor_arrow, 0)
  end
  if option.type == "color" then
    WindowRectOp(WIN, miniwin.rect_fill, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y + 1, POSITION.WINDOW_WIDTH - 5 - consts.GetBorderWidth(), y + SIZES.LINE_HEIGHT - 1, option.raw_value)
    WindowRectOp(WIN, miniwin.rect_frame, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y + 1, POSITION.WINDOW_WIDTH - 5 - consts.GetBorderWidth(), y + SIZES.LINE_HEIGHT - 1, consts.white)
    if option.enabled == nil or option.enabled == true then
      WindowAddHotspot(WIN, parent_key .. "|" .. key, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y + 1, POSITION.WINDOW_WIDTH - 5 - consts.GetBorderWidth(), y + SIZES.LINE_HEIGHT - 1, "", "", "", "", "configuration_onChangeOption", "click to change", miniwin.cursor_hand, 0)
    end
  elseif option.type == "number" then
    if option.value == nil then option.value = tostring(option.raw_value) end
    local b_width = WindowTextWidth(WIN, FONT, "-")
    local v_width = WindowTextWidth(WIN, FONT, option.value)
    local minus_color = consts.white
    local add_color = consts.white
    if option.raw_value == nil then option.raw_value = tonumber(option.value or 0) end
    if option.enabled == false or (option.min ~= nil and option.raw_value <= option.min) then minus_color = consts.dimgray end
    if option.enabled == false or (option.max ~= nil and option.raw_value >= option.max) then add_color = consts.dimgray end
    WindowText(WIN, FONT, "-", SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y, 0, 0, minus_color, true)
    WindowText(WIN, FONT, "+", SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + v_width + b_width * 3, y, 0, 0, add_color, true)
    
    if option.enabled == false then
      WindowText(WIN, FONT, tostring(option.value), SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + b_width * 2, y, 0, 0, consts.dimgray, true)
    else
      WindowText(WIN, FONT_UNDERLINE, tostring(option.value), SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + b_width * 2, y, 0, 0, consts.white, true)
      WindowAddHotspot(WIN, parent_key .. "|" .. key .. "|minus", SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y+1, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + b_width, y + SIZES.LINE_HEIGHT - 1, "", "", "", "", "configuration_onChangeOption", "click to decrease (shift+ctrl, shift, ctrl for 100, 50, 10)", miniwin.cursor_hand, 0)
      WindowAddHotspot(WIN, parent_key .. "|" .. key, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + b_width * 2, y+1, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + v_width + b_width * 2, y + SIZES.LINE_HEIGHT - 1, "", "", "", "", "configuration_onChangeOption", "click to change", miniwin.cursor_hand, 0)
      WindowAddHotspot(WIN, parent_key .. "|" .. key .. "|add", SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + v_width + b_width * 3, y+1, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + v_width + b_width * 4, y + SIZES.LINE_HEIGHT - 1, "", "", "", "", "configuration_onChangeOption", "click to increase (shift+ctrl, shift, ctrl for 100, 50, 10)", miniwin.cursor_hand, 0)
    end    
  else
    if option.value == nil then option.value = tostring(option.raw_value) end
    local v_width = WindowTextWidth(WIN, FONT, option.value)
    if option.enabled == false then
      WindowText(WIN, FONT, tostring(option.value), SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y, 0, 0, consts.dimgray, true)
    else
      WindowText(WIN, FONT_UNDERLINE, tostring(option.value), SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y, 0, 0, consts.white, true)
      WindowAddHotspot(WIN, parent_key .. "|" .. key, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth(), y+1, SIZES.LABEL_WIDTH + 20 + consts.GetBorderWidth() + v_width, y + SIZES.LINE_HEIGHT - 1, "", "", "", "", "configuration_onChangeOption", "click to change", miniwin.cursor_hand, 0)
    end
  end

  return y + SIZES.LINE_HEIGHT
end

hide = function()
  CONFIG = nil
  WindowShow(WIN, false)
end

function configuration_onClose(flags, hotspot_id)
  hide()
end

function configuration_onChangeOption(flags, hotspot_id)
  local ids = utils.split(hotspot_id, "|")
  local group_id, option_id = ids[1], ids[2]
  local opt_mode = ids[3]
  local nested_groups = utils.split(group_id, "^")
  local group = CONFIG[nested_groups[1]]
  local num = 1

  for i = 2, #nested_groups do
    group = group[nested_groups[i]]
  end

  if opt_mode then
    if bit.band(flags, 0x01) ~= 0 and bit.band(flags, 0x02) then
      num = 100
    elseif bit.band(flags, 0x01) ~= 0 then
      num = 50
    elseif bit.band(flags, 0x02) ~= 0 then
      num = 10
    end
  end

  local option = group[option_id]
  if option.type == "number" then changeNumber(option, opt_mode, num)
  elseif option.type == "text" then changeText(option)
  elseif option.type == "color" then changeColor(option)
  elseif option.type == "font" then changeFont(option)
  elseif option.type == "bool" then changeBool(option)
  elseif option.type == "list" then changeList(option)
  end

  SAVE_CALLBACK(group_id, option_id, option)
end

function configuration_onExpandCollapse(flags, hotspot_id)
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

changeNumber = function(option, opt_mode, num)
  if opt_mode ~= nil then
    local current = option.raw_value
    if opt_mode == "minus" then    
      option.raw_value = current - num
    elseif opt_mode == "add" then
      option.raw_value = current + num
    end
    if option.min ~= nil and option.max ~= nil then
      option.raw_value = math.max(option.min, math.min(option.raw_value, option.max))
    end
    option.value = tostring(option.raw_value)
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

changeText = function(option)
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

changeColor = function(option)
  local new_color = PickColour(option.raw_value)
  if new_color >= 0 then
    option.value = new_color
    option.raw_value = new_color
  end
  show()
end

changeFont = function(option)
  local new_font = utils.fontpicker(option.raw_value.name, option.raw_value.size, option.raw_value.colour)

  if new_font ~= nil then
    option.value = new_font.name
    option.raw_value = new_font
  end
  show()
end

changeBool = function(option)
  option.raw_value = not option.raw_value
  if option.raw_value then
    option.value = "true"
  else
    option.value = "false"
  end
  show()
end

changeList = function(option)
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

validateNumber = function(min, max)
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

calculate = function()
  local height = 4 + consts.GetBorderWidth() + SIZES.LINE_HEIGHT
  local l_width, v_width = 0, 0
  for key, group in consts.pairsByKeys(CONFIG) do
    height, l_width, v_width = measureSection(0, height, key, group, l_width, v_width)
  end

  WindowDeleteAllHotspots(WIN)
    
  SIZES.LABEL_WIDTH = math.max(SIZES.LABEL_WIDTH, l_width)
  SIZES.VALUE_WIDTH = math.max(SIZES.VALUE_WIDTH, v_width + WindowTextWidth(WIN, FONT, "- + "))
  POSITION.WINDOW_HEIGHT = math.min(height + consts.GetBorderWidth(), consts.GetOutputHeight() - 50)
  POSITION.WINDOW_WIDTH = math.min(SIZES.LABEL_WIDTH + 25 + SIZES.VALUE_WIDTH + (consts.GetBorderWidth() * 2), consts.GetOutputWidth() - 50)
  POSITION.WINDOW_LEFT = ((consts.GetOutputWidth()) / 2 + consts.GetOutputLeft()) - POSITION.WINDOW_WIDTH / 2
  POSITION.WINDOW_TOP = ((consts.GetOutputHeight()) / 2 + consts.GetOutputTop()) - POSITION.WINDOW_HEIGHT / 2
end

measureSection = function(indents, height, key, group, l_width, v_width)
  height = height + SIZES.LINE_HEIGHT
  if height > consts.GetOutputHeight() then
    Note("Config screen is too big, collapse some sections.")
    return height, l_width, v_width
  end
  if SECTION_STATUS[key] == nil then
    if string.find(key, "%^") == nil then 
      SECTION_STATUS[key] = true
    else
      SECTION_STATUS[key] = false
    end
  end
  if SECTION_STATUS[key] then
    for k, v in consts.pairsByKeys(group) do
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

measureOption = function(indents, height, parent_key, key, option, l_width, v_width)
  if option == nil then return height, l_width, v_width end
  if option.label == nil then option.label = key:lower():gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end) end
  if option.value == nil then option.value = tostring(option.raw_value) end
  local marker = "  * "
  for i = 1, indents do marker = " " .. marker end
  local label_width = WindowTextWidth(WIN, FONT, marker .. option.label)
  local value_width = WindowTextWidth(WIN, FONT, option.value)
  if label_width > l_width then l_width = label_width end
  if option.type ~= "color" and value_width > v_width then v_width = value_width end
  return height + SIZES.LINE_HEIGHT, l_width, v_width
end

createFontOption = function(sort, label, font, hint, enabled)
  if enabled == nil then enabled = true end
  return {
    sort = sort,
    label = label,
    type = "font",
    value = font.name .. " (" .. font.size .. ")",
    raw_value = font,
    hint = hint or "",
    enabled = enabled
  }
end

createNumberOption = function(sort, label, number, min, max, hint, enabled)
  if enabled == nil then enabled = true end
  return {
    sort = sort,
    label = label,
    type = "number",
    value = tostring(number),
    raw_value = number or 0,
    min = min,
    max = max,
    hint = hint or "",
    enabled = enabled
  }
end

createTextOption = function(sort, label, text, hint, enabled)
  if enabled == nil then enabled = true end
  return {
    sort = sort,
    label = label,
    type = "text",
    value = text,
    raw_value = text,
    hint = hint or "",
    enabled = enabled
  }
end

createBoolOption = function(sort, label, bool, hint, enabled)
  if enabled == nil then enabled = true end
  return {
    sort = sort,
    label = label,
    type = "bool",
    value = tostring(bool),
    raw_value = bool,
    hint = hint or "",
    enabled = enabled
  }
end

createColorOption = function(sort, label, color, hint, enabled)
  if enabled == nil then enabled = true end
  return {
    sort = sort,
    label = label,
    type = "color",
    value = color or consts.black,
    raw_value = color,
    hint = hint or "",
    enabled = enabled
  }
end

createListOption = function(sort, label, selection, list, hint, enabled)
  if enabled == nil then enabled = true end
  local raw = 0
  for i, opt in ipairs(list) do
    if Trim(opt:lower()) == Trim(selection:lower()) then
      raw = i
      break
    end
  end
  return {
    sort = sort,
    label = label,
    type = "list",
    value = selection,
    raw_value = idx,
    list = list,
    hint = hint or "",
    enabled = enabled
  }
end

return {
  Show = show,
  Hide = hide,
  Update = update, 
  CreateFontOption = createFontOption, 
  CreateNumberOption = createNumberOption, 
  CreateTextOption = createTextOption,
  CreateBoolOption = createBoolOption, 
  CreateColorOption = createColorOption, 
  CreateListOption = createListOption
}