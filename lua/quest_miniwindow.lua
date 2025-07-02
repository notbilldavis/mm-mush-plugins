local config_window = require "configuration_miniwindow"

local WIN = GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local QUESTFONT = WIN .. "_quest_font"
local QUESTFONT_STRIKE = WIN .. "_quest_font_strike"
local QUESTFONT_UNDERLINE = WIN .. "_quest_font_underline"

local CONFIG = nil

local WINDOW_WIDTH = 50
local WINDOW_HEIGHT = 25
local LINE_HEIGHT = nil

local CURRENT_BUTTON_COLOR
local CURRENT_LABEL_COLOR 

local BUTTON_X = nil
local BUTTON_Y = nil
local DRAG_X = nil
local DRAG_Y = nil

local TEXT_BUFFER = { }
local FORMATTED_LINES = { }

local EXPANDED = true
local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

function InitializeMiniWindow()
  loadSavedData()
  createWindowAndFont()
  drawMiniWindow()
end

function loadSavedData()
  local serialized_config = GetVariable("quest_config") or ""
  if serialized_config == "" then
    CONFIG = {
      BUTTON_FONT = { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 },
      QUEST_FONT = { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 },
      BUTTON_WIDTH = 100,
      BUTTON_HEIGHT = 25,
      LOCK_POSITION = false,
      EXPAND_DOWN = false,
      EXPAND_RIGHT = false,
      HIDE_EMPTY = false,
      BACKGROUND_COLOR = 0,
      BORDER_COLOR = 12632256,
      BUTTON_LABEL = "Quest",
      ACTIVE_BUTTON_COLOR = 8421504,
      ACTIVE_LABEL_COLOR = 16777215,
      DISABLED_BUTTON_COLOR = 6908265,
      DISABLED_LABEL_COLOR = 8421504
    }
  else
    CONFIG = Deserialize(serialized_config)
  end
  
  BUTTON_X = GetVariable("quest_buttonx") or GetInfo(292) - CONFIG.BUTTON_WIDTH - 25
  BUTTON_Y = GetVariable("quest_buttony") or GetInfo(293) - CONFIG.BUTTON_HEIGHT - 25
end

function createWindowAndFont()
  if CONFIG == nil then return end

  local buttonfont = CONFIG["BUTTON_FONT"]
  local questfont = CONFIG["QUEST_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, BUTTONFONT, buttonfont.name, buttonfont.size, 
    convertToBool(buttonfont.bold), 
    convertToBool(buttonfont.italic), 
    convertToBool(buttonfont.underline), 
    convertToBool(buttonfont.strikeout))

  WindowFont(WIN, QUESTFONT, questfont.name, questfont.size)
  WindowFont(WIN, QUESTFONT_STRIKE, questfont.name, questfont.size, false, false, false, true)
  WindowFont(WIN, QUESTFONT_UNDERLINE, questfont.name, questfont.size, false, false, true, false)

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1) - WindowFontInfo(WIN, BUTTONFONT, 4) + 2
end

function drawMiniWindow()
  if CONFIG ~= nil and not CONFIG.HIDE_EMPTY or #TEXT_BUFFER > 0 then
    WindowShow(WIN, false)

    setSizeAndPositionToContent()
    drawToggleButton()
    drawQuestWindows()
    drawQuestText()
    
    WindowShow(WIN, true)
  end
end

function setSizeAndPositionToContent()
  local left = math.max(WindowInfo(WIN, 1), 0)
  local top = math.max(WindowInfo(WIN, 2), 0)
  local right = left + WindowInfo(WIN, 3)
  local bottom = top + WindowInfo(WIN, 4)

  local final_width = CONFIG.BUTTON_WIDTH
  local column1Final, column2Final = 0, 0
  local final_height = CONFIG.BUTTON_HEIGHT

  if TEXT_BUFFER == nil then
    TEXT_BUFFER = { }
  end

  CURRENT_BUTTON_COLOR = CONFIG.ACTIVE_BUTTON_COLOR
  CURRENT_LABEL_COLOR = CONFIG.ACTIVE_LABEL_COLOR

  if #TEXT_BUFFER == 0 then
    CURRENT_BUTTON_COLOR = CONFIG.DISABLED_BUTTON_COLOR
    CURRENT_LABEL_COLOR = CONFIG.DISABLED_LABEL_COLOR
    EXPANDED = false
  end

  if #TEXT_BUFFER == 0 then
    EXPANDED = false
  end

  if EXPANDED then
    final_height = #TEXT_BUFFER * LINE_HEIGHT + CONFIG.BUTTON_HEIGHT + 4

    for _, styles in ipairs(TEXT_BUFFER) do
      local currentWidth = 0

      for _, seg in ipairs(styles) do
        currentWidth = currentWidth + WindowTextWidth(WIN, BUTTONFONT, seg.text)
      end

      if currentWidth > final_width then
        final_width = currentWidth
      end
    end
  end

  WINDOW_WIDTH = math.max(final_width, CONFIG.BUTTON_WIDTH)
  WINDOW_HEIGHT = math.max(final_height, CONFIG.BUTTON_HEIGHT)

  local new_left = 0
  local new_top = 0

  BUTTON_X = BUTTON_X or left
  BUTTON_Y = BUTTON_Y or top

  if CONFIG.EXPAND_RIGHT then
    new_left = BUTTON_X
  else
    new_left = BUTTON_X - WINDOW_WIDTH
  end

  if CONFIG.EXPAND_DOWN then
    new_top = BUTTON_Y
  else
    new_top = BUTTON_Y - WINDOW_HEIGHT
  end

  WindowPosition(WIN, new_left, new_top, 4, 2)
  WindowResize(WIN, WINDOW_WIDTH, WINDOW_HEIGHT, 0)
  WindowSetZOrder(WIN, 9999)
end

function drawToggleButton()
  local text_width = WindowTextWidth(WIN, BUTTONFONT, CONFIG.BUTTON_LABEL)
  local left = 0
  local top = 0
  local right = CONFIG.BUTTON_WIDTH  
  local bottom = CONFIG.BUTTON_HEIGHT

  if not CONFIG.EXPAND_RIGHT then
    left = WINDOW_WIDTH - CONFIG.BUTTON_WIDTH
    right = WINDOW_WIDTH
  end

  if not CONFIG.EXPAND_DOWN then
    top = WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT
    bottom = WINDOW_HEIGHT
  end

  local button_width = CONFIG.BUTTON_WIDTH
  local button_right = right
  if not CONFIG.LOCK_POSITION then 
    button_width = button_width - 25
    button_right = button_right - 25 
  end

  WindowRectOp(WIN, miniwin.rect_fill, left, top, button_right, bottom, CURRENT_BUTTON_COLOR)
  WindowText(WIN, BUTTONFONT, CONFIG.BUTTON_LABEL, left + (button_width / 2) - (text_width / 2), top + 8, 0, 0, CURRENT_LABEL_COLOR)

  local cursor = miniwin.cursor_arrow
  if #TEXT_BUFFER > 0 then
    cursor = miniwin.cursor_hand
  end

  WindowAddHotspot(WIN, "quest", left, top, button_right, bottom, "", "", "", "", "quest_button_click", "", cursor, 0)

  if not CONFIG.LOCK_POSITION then
    WindowRectOp(WIN, miniwin.rect_fill, button_right, top, right, bottom, CURRENT_BUTTON_COLOR)
    WindowLine(WIN, button_right + 3, top + 8, right - 3, top + 8, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 12, right - 3, top + 12, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 16, right - 3, top + 16, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)

    WindowAddHotspot(WIN, "drag_" .. WIN, button_right, top, right, bottom, "", "", "quest_drag_mousedown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "quest_drag_move", "quest_drag_release", 0)
  end
end

function quest_drag_mousedown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)
end

function quest_drag_move(flags, hotspot_id)
  local pos_x = clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - WINDOW_WIDTH)
  local pos_y = clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function quest_drag_release(flags, hotspot_id)
  Repaint()
  SetVariable("quest_buttonx", getButtonX())
  SetVariable("quest_buttony", getButtonY())
end

function drawQuestWindows()
  if EXPANDED then
    local top = 0
    local bottom = WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT

    local left_clear = 0
    local top_clear = WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT
    local right_clear = WINDOW_WIDTH - CONFIG.BUTTON_WIDTH
    local bottom_clear = WINDOW_HEIGHT

    if CONFIG.EXPAND_DOWN then
      top = CONFIG.BUTTON_HEIGHT
      bottom = WINDOW_HEIGHT

      top_clear = 0
      bottom_clear = CONFIG.BUTTON_HEIGHT
    end

    if CONFIG.EXPAND_RIGHT then
      left_clear = CONFIG.BUTTON_WIDTH
      right_clear = WINDOW_WIDTH
    end

    WindowRectOp(WIN, miniwin.rect_fill, 0, top, WINDOW_WIDTH, bottom, CONFIG.BACKGROUND_COLOR)
    WindowRectOp(WIN, miniwin.rect_frame, 0, top, WINDOW_WIDTH, bottom, CONFIG.BORDER_COLOR)
    WindowRectOp(WIN, miniwin.rect_fill, left_clear, top_clear, right_clear, bottom_clear, ColourNameToRGB("black"))
  end
end

function drawQuestText()
  if EXPANDED then
    local y = 4
    if CONFIG.EXPAND_DOWN then
      y = y + CONFIG.BUTTON_HEIGHT
    end
    
    for i = 1, #TEXT_BUFFER do
      local x = 4
      if y + LINE_HEIGHT > WINDOW_HEIGHT then
        break
      end

      local lineText = ""
      local segments = TEXT_BUFFER[i]
      for _, s in ipairs(segments) do
        lineText = lineText .. s.text
        local w = WindowTextWidth(WIN, BUTTONFONT, s.text)
        if s.textcolour == ColourNameToRGB("dimgray") then
          WindowText(WIN, QUESTFONT_STRIKE, s.text, x + 2, y, 0, 0, s.textcolour)
        else
          local room_name = string.match(s.text , "^Journey to%s+(.+)$")
          if room_name then
            WindowText(WIN, QUESTFONT_UNDERLINE, s.text, x + 2, y, 0, 0, s.textcolour)
            WindowAddHotspot(WIN, room_name, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_phase_click", "", miniwin.cursor_hand, 0)
          else
            WindowText(WIN, BUTTONFONT, s.text, x + 2, y, 0, 0, s.textcolour)
          end
        end      

        x = x + w
      end

      if #lineText > 0 then
        y = y + LINE_HEIGHT
      end
    end
  end
end

function AddLine(segments)
  if CONFIG == nil then
    InitializeMiniWindow()
  end

  EXPANDED = true

  if TEXT_BUFFER == nil then 
    clearMiniWindow()
  end

  table.insert(TEXT_BUFFER, segments)

  drawMiniWindow()
end

function quest_phase_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    Execute("mapper find " .. hotspot_id)
  end
end

function quest_button_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if #TEXT_BUFFER > 0 then
      EXPANDED = not EXPANDED
      drawMiniWindow()
    end
  end
  if flags == miniwin.hotspot_got_rh_mouse then
    local menu_items = ""
    if CONFIG.LOCK_POSITION then menu_items = menu_items .. "+" end
    menu_items = menu_items .. "Lock Position | >Anchor | "
    for _, a in ipairs(ANCHOR_LIST) do
      menu_items = menu_items .. a .. " | "
    end
    menu_items = menu_items .. " < |-| Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Lock Position" then
      CONFIG.LOCK_POSITION = not CONFIG.LOCK_POSITION
    elseif result == "Configure" then
      configure()
    else
      for i, a in ipairs(ANCHOR_LIST) do
        if result == a then
          adjustAnchor(i)
        end
      end
    end

    saveMiniWindow()
    drawMiniWindow()
  end
end

function clearMiniWindow() 
  TEXT_BUFFER = {}
  FORMATTED_LINES = {}
  EXPANDED = false
  WindowDeleteAllHotspots(WIN)
  drawMiniWindow()
end

function closeMiniWindow()
  saveMiniWindow()
  WindowShow(WIN, false)
end

function saveMiniWindow()
  SetVariable("quest_config", Serialize(CONFIG))
  SetVariable("quest_buttonx", getButtonX())
  SetVariable("quest_buttony", getButtonY())
  SaveState()
end

function configure()
  local config = {
    Quest = {
      BUTTON_FONT = { type = "font", value = CONFIG.BUTTON_FONT.name .. " (" .. CONFIG.BUTTON_FONT.size .. ")", raw_value = CONFIG.BUTTON_FONT },
      QUEST_FONT = { type = "font", value = CONFIG.QUEST_FONT.name .. " (" .. CONFIG.QUEST_FONT.size .. ")", raw_value = CONFIG.QUEST_FONT },
      BUTTON_WIDTH = { type = "number", raw_value = CONFIG.BUTTON_WIDTH, min = 50, max = 400 },
      BUTTON_HEIGHT = { type = "number", raw_value = CONFIG.BUTTON_HEIGHT, min = 50, max = 400 },
      LOCK_POSITION = { type = "bool", raw_value = CONFIG.LOCK_POSITION },
      EXPAND_DOWN = { type = "bool", raw_value = CONFIG.EXPAND_DOWN },
      EXPAND_RIGHT = { type = "bool", raw_value = CONFIG.EXPAND_RIGHT },
      HIDE_EMPTY = { label = "Hide When Empty", type = "bool", raw_value = CONFIG.HIDE_EMPTY },
      BACKGROUND_COLOR = { type = "color", raw_value = CONFIG.BACKGROUND_COLOR },
      BORDER_COLOR = { type = "color", raw_value = CONFIG.BORDER_COLOR },
      BUTTON_LABEL = { type = "text", raw_value = CONFIG.BUTTON_LABEL },
      ACTIVE_BUTTON_COLOR = { type = "color", raw_value = CONFIG.ACTIVE_BUTTON_COLOR },
      ACTIVE_LABEL_COLOR = { type = "color", raw_value = CONFIG.ACTIVE_LABEL_COLOR },
      DISABLED_BUTTON_COLOR = { type = "color", raw_value = CONFIG.DISABLED_BUTTON_COLOR },
      DISABLED_LABEL_COLOR = { type = "color", raw_value = CONFIG.DISABLED_LABEL_COLOR },
      ANCHOR = { type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST }
    }
  }
  
  config_window.Show(config, configureDone)
end

function configureDone(group_id, option_id, config)
  if option == "ANCHOR" then
    adjustAnchor(config.raw_value)
  else
    CONFIG[option_id] = config.raw_value
  end

  createWindowAndFont()
  drawMiniWindow()
  saveMiniWindow()
end

function adjustAnchor(anchor_idx)
  local anchor = ANCHOR_LIST[anchor_idx]:sub(4)
  if anchor == nil or anchor == "" or anchor == "None" then
    return
  elseif anchor == "Top Left (Window)" then 
    BUTTON_X = 10
    BUTTON_Y = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Window)" then 
    BUTTON_X = 10
    BUTTON_Y = GetInfo(280) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Top Right (Window)" then
    BUTTON_X = GetInfo(281) - CONFIG.BUTTON_WIDTH - 10
    BUTTON_Y = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Bottom Right (Window)" then
    BUTTON_X = GetInfo(281) - CONFIG.BUTTON_WIDTH - 10
    BUTTON_Y = GetInfo(280) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Top Left (Output)" then
    BUTTON_X = GetInfo(290) + 10
    BUTTON_Y = GetInfo(291) + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Output)" then
    BUTTON_X = GetInfo(290) + 10
    BUTTON_Y = GetInfo(293) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor ==  "Top Right (Output)" then
    BUTTON_X = GetInfo(292) - 10
    BUTTON_Y = GetInfo(291) + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor ==  "Bottom Right (Output)" then
    BUTTON_X = GetInfo(292) - 10
    BUTTON_Y = GetInfo(293) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = false
  end

  setSizeAndPositionToContent()
end

function getButtonX()
  if CONFIG.EXPAND_RIGHT then
    return WindowInfo(WIN, 10)
  end
  
  return WindowInfo(WIN, 12)
end

function getButtonY()
  if CONFIG.EXPAND_DOWN then
    return WindowInfo(WIN, 11)
  end
  
  return WindowInfo(WIN, 13)
end

function clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

function convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

function showWindow()
  WindowShow(WIN, true)
end

function hideWindow()
  WindowShow(WIN, false)
end

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