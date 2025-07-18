local config_window = require "configuration_miniwindow"

local BAMW = {}
local bamw = {}

local WIN = "badaffects_" .. GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local AFFECTSFONT = WIN .. "_affects_font"

local BA_CONFIGURATION = nil

local WINDOW_WIDTH = 100
local WINDOW_HEIGHT = 25
local LINE_HEIGHT = nil
local COL_1_WIDTH = 0
local COL_2_WIDTH = 0

local CURRENT_BUTTON_COLOR
local CURRENT_LABEL_COLOR 

local BUTTON_X = nil
local BUTTON_Y = nil
local DRAG_X = nil
local DRAG_Y = nil

local TEXT_BUFFER = { }
local BAD_STUFF = { }

local EXPANDED = true
local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

local CHARACTER_NAME = ""

function BAMW.InitializeMiniWindow(character_name)
  CHARACTER_NAME = character_name

  bamw.loadSavedData()
  bamw.createWindowAndFont()  
  BAMW.DrawMiniWindow()
end

function bamw.loadSavedData()
  local serialized_config = GetVariable(CHARACTER_NAME .. "_badaffects_config") or ""
  if serialized_config == "" then
    BA_CONFIGURATION = { }  
  else
    BA_CONFIGURATION = Deserialize(serialized_config)
  end

  BA_CONFIGURATION.BUTTON_FONT = bamw.getValueOrDefault(BA_CONFIGURATION.BUTTON_FONT,  { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  BA_CONFIGURATION.AFFECTS_FONT = bamw.getValueOrDefault(BA_CONFIGURATION.AFFECTS_FONT,  { name = "Lucida Console", size = 9, colour = 255, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  BA_CONFIGURATION.BUTTON_WIDTH = bamw.getValueOrDefault(BA_CONFIGURATION.BUTTON_WIDTH,  100)
  BA_CONFIGURATION.BUTTON_HEIGHT = bamw.getValueOrDefault(BA_CONFIGURATION.BUTTON_HEIGHT,  25)
  BA_CONFIGURATION.LOCK_POSITION = bamw.getValueOrDefault(BA_CONFIGURATION.LOCK_POSITION,  false)
  BA_CONFIGURATION.EXPAND_DOWN = bamw.getValueOrDefault(BA_CONFIGURATION.EXPAND_DOWN,  false)
  BA_CONFIGURATION.EXPAND_RIGHT = bamw.getValueOrDefault(BA_CONFIGURATION.EXPAND_RIGHT,  false)
  BA_CONFIGURATION.ENABLED = bamw.getValueOrDefault(BA_CONFIGURATION.ENABLED,  true)
  BA_CONFIGURATION.BACKGROUND_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.BACKGROUND_COLOR,  0)
  BA_CONFIGURATION.BORDER_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.BORDER_COLOR,  12632256)
  BA_CONFIGURATION.BUTTON_LABEL = bamw.getValueOrDefault(BA_CONFIGURATION.BUTTON_LABEL,  "Affects")
  BA_CONFIGURATION.ACTIVE_BUTTON_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.ACTIVE_BUTTON_COLOR,  8421504)
  BA_CONFIGURATION.ACTIVE_LABEL_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.ACTIVE_LABEL_COLOR,  16777215)
  BA_CONFIGURATION.DISABLED_BUTTON_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.DISABLED_BUTTON_COLOR,  6908265)
  BA_CONFIGURATION.DISABLED_LABEL_COLOR = bamw.getValueOrDefault(BA_CONFIGURATION.DISABLED_LABEL_COLOR,  842150)
  
  BUTTON_X = GetVariable(CHARACTER_NAME .. "_badaffects_buttonx") or GetInfo(292) - BA_CONFIGURATION.BUTTON_WIDTH - 25
  BUTTON_Y = GetVariable(CHARACTER_NAME .. "_badaffects_buttony") or GetInfo(293) - BA_CONFIGURATION.BUTTON_HEIGHT - 25
end

function bamw.createWindowAndFont()
  if BA_CONFIGURATION == nil then return end

  local btnfont = BA_CONFIGURATION["BUTTON_FONT"]
  local afffont = BA_CONFIGURATION["AFFECTS_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, BUTTONFONT, btnfont.name, btnfont.size, 
    bamw.convertToBool(btnfont.bold), 
    bamw.convertToBool(btnfont.italic), 
    bamw.convertToBool(btnfont.underline), 
    bamw.convertToBool(btnfont.strikeout))

  WindowFont(WIN, AFFECTSFONT, afffont.name, afffont.size, 
    bamw.convertToBool(afffont.bold), 
    bamw.convertToBool(afffont.italic), 
    bamw.convertToBool(afffont.underline), 
    bamw.convertToBool(afffont.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1) - WindowFontInfo(WIN, BUTTONFONT, 4) + 2
end

function BAMW.DrawMiniWindow()
  if BA_CONFIGURATION ~= nil and BA_CONFIGURATION.ENABLED and WIN then
    WindowShow(WIN, false)

    bamw.setSizeAndPositionToContent()
    bamw.drawToggleButton()
    bamw.drawAffectsWindows()
    bamw.drawAffectsText()

    WindowShow(WIN, true)
  end
end

function BAMW.ClearMiniWindow() 
  TEXT_BUFFER = {}
  EXPANDED = false
  BAMW.DrawMiniWindow()
end

function BAMW.CloseMiniWindow()
  BAMW.SaveMiniWindow()
  WindowShow(WIN, false)  
end

function BAMW.SaveMiniWindow()
  SetVariable(CHARACTER_NAME .. "_badaffects_config", Serialize(BA_CONFIGURATION))
  SetVariable(CHARACTER_NAME .. "_badaffects_buttonx", bamw.getButtonX())
  SetVariable(CHARACTER_NAME .. "_badaffects_buttony", bamw.getButtonY())
end

function BAMW.GetConfiguration()
  local config = {
    BUTTON_FONT = { label = "Button Font", type = "font", value = BA_CONFIGURATION.BUTTON_FONT.name .. " (" .. BA_CONFIGURATION.BUTTON_FONT.size .. ")", raw_value = BA_CONFIGURATION.BUTTON_FONT },
    AFFECTS_FONT = { label = "Affects Font", type = "font", value = BA_CONFIGURATION.AFFECTS_FONT.name .. " (" .. BA_CONFIGURATION.AFFECTS_FONT.size .. ")", raw_value = BA_CONFIGURATION.AFFECTS_FONT },
    BUTTON_WIDTH = { type = "number", raw_value = BA_CONFIGURATION.BUTTON_WIDTH, min = 50, max = 400 },
    BUTTON_HEIGHT = { type = "number", raw_value = BA_CONFIGURATION.BUTTON_HEIGHT, min = 50, max = 400 },
    ENABLED = { label = "Enabled", type = "bool", value = tostring(BA_CONFIGURATION.ENABLED), raw_value = BA_CONFIGURATION.ENABLED },    
    LOCK_POSITION = { label = "Lock Position", type = "bool", value = tostring(BA_CONFIGURATION.LOCK_POSITION), raw_value = BA_CONFIGURATION.LOCK_POSITION },
    EXPAND_DOWN = { label = "Expand Down", type = "bool", value = tostring(BA_CONFIGURATION.EXPAND_DOWN), raw_value = BA_CONFIGURATION.EXPAND_DOWN },
    EXPAND_RIGHT = { label = "Expand Right", type = "bool", value = tostring(BA_CONFIGURATION.EXPAND_RIGHT), raw_value = BA_CONFIGURATION.EXPAND_RIGHT },
    BACKGROUND_COLOR = { label = "Background Color", type = "color", value = BA_CONFIGURATION.BACKGROUND_COLOR, raw_value = BA_CONFIGURATION.BACKGROUND_COLOR },
    BORDER_COLOR = { label = "Border Color", type = "color", value = BA_CONFIGURATION.BORDER_COLOR, raw_value = BA_CONFIGURATION.BORDER_COLOR },
    BUTTON_LABEL = { label = "Button Label", type = "text", value = BA_CONFIGURATION.BUTTON_LABEL, raw_value = BA_CONFIGURATION.BUTTON_LABEL },
    ACTIVE_BUTTON_COLOR = { label = "Active Button Color", type = "color", value = BA_CONFIGURATION.ACTIVE_BUTTON_COLOR, raw_value = BA_CONFIGURATION.ACTIVE_BUTTON_COLOR },
    ACTIVE_LABEL_COLOR = { label = "Active Label Color", type = "color", value = BA_CONFIGURATION.ACTIVE_LABEL_COLOR, raw_value = BA_CONFIGURATION.ACTIVE_LABEL_COLOR },
    DISABLED_BUTTON_COLOR = { label = "Disabled Button Color", type = "color", value = BA_CONFIGURATION.DISABLED_BUTTON_COLOR, raw_value = BA_CONFIGURATION.DISABLED_BUTTON_COLOR },
    DISABLED_LABEL_COLOR = { label = "Disabled Label Color", type = "color", value = BA_CONFIGURATION.DISABLED_LABEL_COLOR, raw_value = BA_CONFIGURATION.DISABLED_LABEL_COLOR },
    ANCHOR = { label = "Anchor", type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST }
  }

  return config
end

function BAMW.SaveConfiguration(option, config)
  if option == "ANCHOR" then
    bamw.adjustAnchor(config.raw_value)
  else
    BA_CONFIGURATION[option] = config.raw_value
  end
  
  BAMW.SaveMiniWindow()
  bamw.createWindowAndFont()
  BAMW.DrawMiniWindow()
end

function bamw.adjustAnchor(anchor_idx)
  local anchor = ANCHOR_LIST[anchor_idx]:sub(4)
  if anchor == nil or anchor == "" or anchor == "None" then
    return
  elseif anchor == "Top Left (Window)" then 
    BUTTON_X = 10
    BUTTON_Y = 10
    BA_CONFIGURATION.EXPAND_DOWN = true
    BA_CONFIGURATION.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Window)" then 
    BUTTON_X = 10
    BUTTON_Y = GetInfo(280) - 10
    BA_CONFIGURATION.EXPAND_DOWN = false
    BA_CONFIGURATION.EXPAND_RIGHT = true
  elseif anchor == "Top Right (Window)" then
    BUTTON_X = GetInfo(281) - BA_CONFIGURATION.BUTTON_WIDTH - 10
    BUTTON_Y = 10
    BA_CONFIGURATION.EXPAND_DOWN = true
    BA_CONFIGURATION.EXPAND_RIGHT = false
  elseif anchor == "Bottom Right (Window)" then
    BUTTON_X = GetInfo(281) - BA_CONFIGURATION.BUTTON_WIDTH - 10
    BUTTON_Y = GetInfo(280) - 10
    BA_CONFIGURATION.EXPAND_DOWN = false
    BA_CONFIGURATION.EXPAND_RIGHT = false
  elseif anchor == "Top Left (Output)" then
    BUTTON_X = GetInfo(290) + 10
    BUTTON_Y = GetInfo(291) + 10
    BA_CONFIGURATION.EXPAND_DOWN = true
    BA_CONFIGURATION.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Output)" then
    BUTTON_X = GetInfo(290) + 10
    BUTTON_Y = GetInfo(293) - 10
    BA_CONFIGURATION.EXPAND_DOWN = false
    BA_CONFIGURATION.EXPAND_RIGHT = true
  elseif anchor ==  "Top Right (Output)" then
    BUTTON_X = GetInfo(292) - 10
    BUTTON_Y = GetInfo(291) + 10
    BA_CONFIGURATION.EXPAND_DOWN = true
    BA_CONFIGURATION.EXPAND_RIGHT = false
  elseif anchor ==  "Bottom Right (Output)" then
    BUTTON_X = GetInfo(292) - 10
    BUTTON_Y = GetInfo(293) - 10
    BA_CONFIGURATION.EXPAND_DOWN = false
    BA_CONFIGURATION.EXPAND_RIGHT = false
  end

  --Note("Set anchor points: " .. anchor .. " (" .. BUTTON_X .. ", " .. BUTTON_Y .. ")")

  bamw.setSizeAndPositionToContent()
end

function bamw.setSizeAndPositionToContent()
  local left = math.max(WindowInfo(WIN, 1), 0)
  local top = math.max(WindowInfo(WIN, 2), 0)
  local right = left + WindowInfo(WIN, 3)
  local bottom = top + WindowInfo(WIN, 4)

  local final_width = BA_CONFIGURATION.BUTTON_WIDTH or 100
  local column1Final, column2Final = 0, 0
  local final_height = BA_CONFIGURATION.BUTTON_HEIGHT or 25

  if TEXT_BUFFER == nil then
    TEXT_BUFFER = { }
  end

  for i = #TEXT_BUFFER, 1, -1 do
    local aff = TEXT_BUFFER[i]
    
    if aff == nil or aff.affect == nil or aff.expire == nil or aff.expire - os.time() <= 0 then
      table.remove(TEXT_BUFFER, i)
    end
  end

  CURRENT_BUTTON_COLOR = BA_CONFIGURATION.ACTIVE_BUTTON_COLOR
  CURRENT_LABEL_COLOR = BA_CONFIGURATION.ACTIVE_LABEL_COLOR

  if #TEXT_BUFFER == 0 then
    CURRENT_BUTTON_COLOR = BA_CONFIGURATION.DISABLED_BUTTON_COLOR
    CURRENT_LABEL_COLOR = BA_CONFIGURATION.DISABLED_LABEL_COLOR
    EXPANDED = false
  end

  if #TEXT_BUFFER == 0 then
    EXPANDED = false
  end

  if EXPANDED then
    final_height = #TEXT_BUFFER * LINE_HEIGHT + BA_CONFIGURATION.BUTTON_HEIGHT + 4

    for _, details in ipairs(TEXT_BUFFER) do
      if details ~= nil and details.affect ~= nil and details.expire ~= nil then
        local col1Width = WindowTextWidth(WIN, AFFECTSFONT, details.affect)
        local col2Width = WindowTextWidth(WIN, AFFECTSFONT, bamw.getFriendlyExpire(details.expire))

        if col1Width > column1Final then
          column1Final = col1Width
        end

        if col2Width > column2Final then
          column2Final = col2Width
        end
      end
    end
  end

  local totalCols = column1Final + 22 + column2Final
  if (totalCols > final_width) then
    final_width = totalCols
    COL_1_WIDTH = column1Final
    COL_2_WIDTH = column2Final
  end

  WINDOW_WIDTH = math.max(final_width, BA_CONFIGURATION.BUTTON_WIDTH)
  WINDOW_HEIGHT = math.max(final_height, BA_CONFIGURATION.BUTTON_HEIGHT)

  local new_left = 0
  local new_top = 0

  BUTTON_X = BUTTON_X or left
  BUTTON_Y = BUTTON_Y or top

  if BA_CONFIGURATION.EXPAND_RIGHT then
    new_left = BUTTON_X
  else
    new_left = BUTTON_X - WINDOW_WIDTH
  end

  if BA_CONFIGURATION.EXPAND_DOWN then
    new_top = BUTTON_Y
  else
    new_top = BUTTON_Y - WINDOW_HEIGHT
  end

  WindowPosition(WIN, new_left, new_top, 4, 2)
  WindowResize(WIN, WINDOW_WIDTH, WINDOW_HEIGHT, 0)
  WindowSetZOrder(WIN, 9999)
end

function bamw.drawToggleButton()
  local text_width = WindowTextWidth(WIN, BUTTONFONT, BA_CONFIGURATION.BUTTON_LABEL)
  local left = 0
  local top = 0
  local right = BA_CONFIGURATION.BUTTON_WIDTH  
  local bottom = BA_CONFIGURATION.BUTTON_HEIGHT

  if not BA_CONFIGURATION.EXPAND_RIGHT then
    left = WINDOW_WIDTH - BA_CONFIGURATION.BUTTON_WIDTH
    right = WINDOW_WIDTH
  end

  if not BA_CONFIGURATION.EXPAND_DOWN then
    top = WINDOW_HEIGHT - BA_CONFIGURATION.BUTTON_HEIGHT
    bottom = WINDOW_HEIGHT
  end

  local button_width = BA_CONFIGURATION.BUTTON_WIDTH
  local button_right = right
  if not BA_CONFIGURATION.LOCK_POSITION then 
    button_width = button_width - 25
    button_right = button_right - 25 
  end

  WindowRectOp(WIN, miniwin.rect_fill, left, top, button_right, bottom, CURRENT_BUTTON_COLOR)
  WindowText(WIN, BUTTONFONT, BA_CONFIGURATION.BUTTON_LABEL, left + (button_width / 2) - (text_width / 2), top + 8, 0, 0, CURRENT_LABEL_COLOR)

  local cursor = miniwin.cursor_arrow
  if #TEXT_BUFFER > 0 then
    cursor = miniwin.cursor_hand
  end

  WindowAddHotspot(WIN, "badaffects", left, top, button_right, bottom, "", "", "", "", "badaffects_button_click", "", cursor, 0)

  if not BA_CONFIGURATION.LOCK_POSITION then
    WindowRectOp(WIN, miniwin.rect_fill, button_right, top, right, bottom, CURRENT_BUTTON_COLOR)
    WindowLine(WIN, button_right + 3, top + 8, right - 3, top + 8, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 12, right - 3, top + 12, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 16, right - 3, top + 16, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)

    WindowAddHotspot(WIN, "drag_" .. WIN, button_right, top, right, bottom, "", "", "badaffects_drag_mousedown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "baddaffects_drag_move", "badaffects_drag_release", 0)
  end
end

function badaffects_drag_mousedown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)
end

function baddaffects_drag_move(flags, hotspot_id)
  local pos_x = bamw.clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - WINDOW_WIDTH)
  local pos_y = bamw.clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function badaffects_drag_release(flags, hotspot_id)
  Repaint()
  SetVariable(CHARACTER_NAME .. "_badaffects_buttonx", bamw.getButtonX())
  SetVariable(CHARACTER_NAME .. "_badaffects_buttony", bamw.getButtonY())
end

function bamw.drawAffectsWindows()
  if EXPANDED then
    local top = 0
    local bottom = WINDOW_HEIGHT - BA_CONFIGURATION.BUTTON_HEIGHT

    local left_clear = 0
    local top_clear = WINDOW_HEIGHT - BA_CONFIGURATION.BUTTON_HEIGHT
    local right_clear = WINDOW_WIDTH - BA_CONFIGURATION.BUTTON_WIDTH
    local bottom_clear = WINDOW_HEIGHT

    if BA_CONFIGURATION.EXPAND_DOWN then
      top = BA_CONFIGURATION.BUTTON_HEIGHT
      bottom = WINDOW_HEIGHT

      top_clear = 0
      bottom_clear = BA_CONFIGURATION.BUTTON_HEIGHT
    end

    if BA_CONFIGURATION.EXPAND_RIGHT then
      left_clear = BA_CONFIGURATION.BUTTON_WIDTH
      right_clear = WINDOW_WIDTH
    end

    WindowRectOp(WIN, miniwin.rect_fill, 0, top, WINDOW_WIDTH, bottom, BA_CONFIGURATION.BACKGROUND_COLOR)
    WindowRectOp(WIN, miniwin.rect_frame, 0, top, WINDOW_WIDTH, bottom, BA_CONFIGURATION.BORDER_COLOR)
    WindowRectOp(WIN, miniwin.rect_fill, left_clear, top_clear, right_clear, bottom_clear, ColourNameToRGB("black"))
  end
end

function bamw.drawAffectsText()
  if EXPANDED then
    local y = 4
    if BA_CONFIGURATION.EXPAND_DOWN then
      y = y + BA_CONFIGURATION.BUTTON_HEIGHT
    end
    
    for i = 1, #TEXT_BUFFER do
      local x = 4
      if y + LINE_HEIGHT > WINDOW_HEIGHT then
        break
      end

      local details = TEXT_BUFFER[i]
      
      if details ~= nil and details.affect ~= nil and details.expire ~= nil then
        local expires_in = details.expire - os.time()
        if expires_in > 0 then
          WindowText(WIN, BUTTONFONT, details.affect, x + 2, y, 0, 0, BA_CONFIGURATION.AFFECTS_FONT.colour)
          WindowText(WIN, BUTTONFONT, "-", COL_1_WIDTH + 10, y, 0, 0, BA_CONFIGURATION.BORDER_COLOR)
          WindowText(WIN, BUTTONFONT, bamw.getFriendlyExpire(expires_in), COL_1_WIDTH + 22, y, 0, 0, BA_CONFIGURATION.AFFECTS_FONT.colour)
          y = y + LINE_HEIGHT
        end
      end
    end
  end
end

function BAMW.AddNegativeAffect(aff, time, redraw)
  if BA_CONFIGURATION.ENABLED then
    EXPANDED = true

    if TEXT_BUFFER == nil then 
      BAMW.ClearMiniWindow()
    end

    if time > os.time() then
      table.insert(TEXT_BUFFER, { affect = aff, expire = time })
    end

    if redraw then
      BAMW.DrawMiniWindow()
    end
  end
end

function BAMW.RemoveNegativeAffect(affect, redraw)
  if BA_CONFIGURATION.ENABLED then
    if TEXT_BUFFER == nil then 
      BAMW.ClearMiniWindow()
    end

    for i = #TEXT_BUFFER, 1, -1 do
      if TEXT_BUFFER[i].affect == affect then
        table.remove(TEXT_BUFFER, i)
        break
      end
    end

    if redraw then
      BAMW.DrawMiniWindow()
    end
  end
end

function bamw.getFriendlyExpire(expires_in)
  if (expires_in > 0) then
    local minutes = expires_in / 60
    local mins = math.floor(minutes)
    local secs = math.floor((minutes - mins) * 60) 
    
    return mins .. " minutes and " .. secs .. " seconds.";
  end

  return nil
end

function badaffects_button_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if #TEXT_BUFFER > 0 then
      EXPANDED = not EXPANDED
      BAMW.DrawMiniWindow()
    end
  end
  if flags == miniwin.hotspot_got_rh_mouse then
    local menu_items = ""
    if BA_CONFIGURATION.LOCK_POSITION then menu_items = menu_items .. "+" end
    menu_items = menu_items .. "Lock Position | >Anchor | "
    for _, a in ipairs(ANCHOR_LIST) do
      menu_items = menu_items .. a .. " | "
    end
    menu_items = menu_items .. " < | - | Disable | - | Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Lock Position" then
      BA_CONFIGURATION.LOCK_POSITION = not BA_CONFIGURATION.LOCK_POSITION
    elseif result == "Disable" then
      BA_CONFIGURATION.ENABLED = false
      WindowShow(WIN, false)
    elseif result == "Configure" then
      bamw.configure()
    else
      for i, a in ipairs(ANCHOR_LIST) do
        if result == a then
          bamw.adjustAnchor(i)
        end
      end
    end
    BAMW.SaveMiniWindow()
    BAMW.DrawMiniWindow()
  end
end

function bamw.configure()
  config_window.Show(BAMW.GetConfiguration(), bamw.configureDone)
end

function bamw.configureDone(group_id, option_id, config)
  BAMW.SaveConfiguration(option_id, config)
end

function bamw.getButtonX()
  if BA_CONFIGURATION.EXPAND_RIGHT then
    return WindowInfo(WIN, 10)
  end
  
  return WindowInfo(WIN, 12)
end

function bamw.getButtonY()
  if BA_CONFIGURATION.EXPAND_DOWN then
    return WindowInfo(WIN, 11)
  end
  
  return WindowInfo(WIN, 13)
end

function bamw.clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

-- serialization

function Serialize(table)
  local function serializeValue(value)
    if type(value) == "table" then
      return Serialize(value)
    elseif type(value) == "string" then
      return string.format("%q", value)
    else
      return tostring(value)
    end
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

function Deserialize(serializedTable)
  local func = load("return " .. serializedTable)
  if func then
    return func()
  else
    return nil, "Failed to load string"
  end
end

function bamw.convertFromBool(bool_value)
  if bool_value then
    return 1
  else
    return 0
  end
end

function bamw.convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

function bamw.getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
end

function BAMW._debug()
  BAMW.AddNegativeAffect("fake affect", os.time() + (60 * 5), true)
end

return BAMW