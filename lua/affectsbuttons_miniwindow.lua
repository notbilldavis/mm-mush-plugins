require "gauge"

local AffectsButtons = {}
local _AffectsButtons = {}

local WIN = "affectsbuttons_" .. GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local HEADERFONT = WIN .. "_header_font"

local AB_CONFIGURATION = {
  BUTTON_FONT = { name = "Trebuchet MS", size = 9, colour = 0, bold = 1, italic = 0, underline = 0, strikeout = 0 },
  HEADER_FONT = { name = "Trebuchet MS", size = 9, colour = 12632256, bold = 1, italic = 0, underline = 0, strikeout = 0 },
  WINDOW_WIDTH = 150,
  SHOW_HEADER = true,
  LOCK_POSITION = false,
  STRETCH_HEIGHT = false,
  HEADER_TEXT = "~ Affects ~",
  BACKGROUND_COLOR = 0,
  BORDER_COLOR = 12632256,
  NEUTRAL_COLOR = 8421504,
  EXPIRED_COLOR = 255,
  CASTED_COLOR = 32768,
  EXPIRING_COLOR = 65535,
}

local LINE_HEIGHT = nil
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 25

local CHARACTER_NAME = ""
local BUTTONS = {}
local DURATIONS = {}
local CURRENT_AFFECTS = {}
local PERM_AFFECTS = {}
local BROADCAST = {}

local CURRENT_COMMAND = nil

local WINDOW_LEFT = nil
local WINDOW_TOP = nil
local DRAG_X = nil
local DRAG_Y = nil
local INIT = false

local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

function AffectsButtons.PrepareMiniWindow()
  local serialized_config = GetVariable("last_affectsbuttons_config")
  if serialized_config ~= nil then
    local temp_config = Deserialize(serialized_config)
    WindowCreate(WIN, temp_config.left, temp_config.top, temp_config.width, temp_config.height, 12, 2, temp_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, temp_config.width, temp_config.height, temp_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, temp_config.border)
    WindowShow(WIN, true)
  end
end

function AffectsButtons.InitializeMiniWindow(character_name)
  CHARACTER_NAME = character_name

  _AffectsButtons.loadSavedData()
  _AffectsButtons.createWindowAndFont()

  INIT = true

  AffectsButtons.DrawMiniWindow()
end

function _AffectsButtons.createWindowAndFont()
  local btnfont = AB_CONFIGURATION["BUTTON_FONT"]
  local hdrfont = AB_CONFIGURATION["HEADER_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)

  WindowFont(WIN, BUTTONFONT, btnfont.name, btnfont.size, 
    _AffectsButtons.convertToBool(btnfont.bold), 
    _AffectsButtons.convertToBool(btnfont.italic), 
    _AffectsButtons.convertToBool(btnfont.italic), 
    _AffectsButtons.convertToBool(btnfont.strikeout))

  WindowFont(WIN, HEADERFONT, hdrfont.name, hdrfont.size, 
    _AffectsButtons.convertToBool(hdrfont.bold), 
    _AffectsButtons.convertToBool(hdrfont.italic), 
    _AffectsButtons.convertToBool(hdrfont.italic), 
    _AffectsButtons.convertToBool(hdrfont.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1)

  WINDOW_LEFT = WINDOW_LEFT or WindowInfo(WIN, 1)
  WINDOW_TOP = WINDOW_TOP or WindowInfo(WIN, 2)
end

function AffectsButtons.DrawMiniWindow()
  if not INIT then return end

  WindowShow(WIN, false)

  local height = (#BUTTONS * 30) + 10
  if AB_CONFIGURATION.SHOW_HEADER then height = height + 30 end
  if AB_CONFIGURATION.STRETCH_HEIGHT then height = GetInfo(280) end

  WindowPosition(WIN, WINDOW_LEFT, WINDOW_TOP, 4, 2)
  WindowResize(WIN, AB_CONFIGURATION.WINDOW_WIDTH, height - 2, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, AB_CONFIGURATION.WINDOW_WIDTH, height, AB_CONFIGURATION.BACKGROUND_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, AB_CONFIGURATION.BORDER_COLOR)

  if AB_CONFIGURATION.SHOW_HEADER then
    local text_width = math.min(AB_CONFIGURATION.WINDOW_WIDTH, WindowTextWidth(WIN, HEADERFONT, AB_CONFIGURATION.HEADER_TEXT, true))
    local center_pos_x = (AB_CONFIGURATION.WINDOW_WIDTH - text_width) / 2
    WindowText(WIN, HEADERFONT, AB_CONFIGURATION.HEADER_TEXT, center_pos_x, 8, 0, 0, AB_CONFIGURATION.HEADER_FONT.colour, false)
  end

  if not AB_CONFIGURATION.LOCK_POSITION then
    WindowAddHotspot(WIN, "drag_" .. WIN, 0, 0, AB_CONFIGURATION.WINDOW_WIDTH, 30, "", "", "affectsbuttons_drag_mousedown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "affectsbuttons_drag_move", "affectsbuttons_drag_release", 0)
  end

  local top_pos = 4
  if AB_CONFIGURATION.SHOW_HEADER then top_pos = top_pos + 30 end

  for k, v in ipairs(BUTTONS) do
    top_pos = _AffectsButtons.drawAffect(k, v["affect"], v["title"], v["action"], top_pos)
  end

  WindowShow(WIN, true)
end

function affectsbuttons_drag_mousedown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)
end

function affectsbuttons_drag_move(flags, hotspot_id)
  local pos_x = _AffectsButtons.clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - AB_CONFIGURATION.WINDOW_WIDTH)
  local pos_y = _AffectsButtons.clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function affectsbuttons_drag_release(flags, hotspot_id)
  Repaint()
  SetVariable(CHARACTER_NAME .. "_affectsbuttons_left", WindowInfo(WIN, 10))
  SetVariable(CHARACTER_NAME .. "_affectsbuttons_top", WindowInfo(WIN, 11))
end

function AffectsButtons.ClearMiniWindow()
  CURRENT_AFFECTS = {}
  PERM_AFFECTS = {}
end

function AffectsButtons.CloseMiniWindow()
  if WIN then
    AffectsButtons.SaveMiniWindow()
    WindowShow(WIN, false)
  end
end

function AffectsButtons.SaveMiniWindow()
  if WIN then
    local sticky_options = { 
      left = WindowInfo(WIN, 10), top = WindowInfo(WIN, 11), 
      width = WindowInfo(WIN, 3), height = WindowInfo(WIN, 4), 
      bgcolor = AB_CONFIGURATION.BACKGROUND_COLOR, 
      border = AB_CONFIGURATION.BORDER_COLOR, 
    }

    SetVariable("last_affectsbuttons_config", Serialize(sticky_options))
    SetVariable(CHARACTER_NAME .. "_affectsbuttons_config", Serialize(AB_CONFIGURATION))
    SetVariable(CHARACTER_NAME .. "_affectsbuttons_left", WindowInfo(WIN, 10))
    SetVariable(CHARACTER_NAME .. "_affectsbuttons_top", WindowInfo(WIN, 11))
    SetVariable(CHARACTER_NAME .. "_affectsbuttons_buttons", Serialize(BUTTONS))
  end
end

function AffectsButtons.SetAffect(affect, time, notify)
  local previous_perm = PERM_AFFECTS[affect] or 0
  local previous_temp = CURRENT_AFFECTS[affect] or 0
  local highest_prev = math.max(previous_perm, previous_temp)

  if (time == 0) then
    AffectsButtons.RemoveAffect(affect, notify)
  else
    if time == -1 then
      PERM_AFFECTS[affect] = 1
    else
      CURRENT_AFFECTS[affect] = os.time() + (time / 4 * 60)
      _AffectsButtons.checkDuration(affect)
    end
  end

  _AffectsButtons.checkForNotifyAdd(notify, affect, highest_prev)
  AffectsButtons.DrawMiniWindow()
end

function AffectsButtons.RemoveAffect(affect, notify)
  local previous_perm = PERM_AFFECTS[affect] or 0
  local previous_temp = CURRENT_AFFECTS[affect] or 0
  local highest_prev = math.max(previous_perm, previous_temp)

  CURRENT_AFFECTS[affect] = 0
  PERM_AFFECTS[affect] = 0

  _AffectsButtons.checkForNotifyRemove(notify, affect, highest_prev)
  AffectsButtons.DrawMiniWindow()
end

function _AffectsButtons.checkDuration(affect)
  local expires_in = CURRENT_AFFECTS[affect] - os.time()
  if DURATIONS[affect] == nil or DURATIONS[affect] < expires_in then
    DURATIONS[affect] = expires_in
    SetVariable("affects_durations", Serialize(DURATIONS))
    SaveState()
  end
end

function _AffectsButtons.checkForNotifyAdd(notify, affect, highest_prev)
  if notify and highest_prev == 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU GAINED " .. affect:upper() .. " !!!")
  end
end

function _AffectsButtons.checkForNotifyRemove(notify, affect, highest_prev)
  if notify and highest_prev > 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU LOST " .. affect:upper() .. " !!!")
  end
end

function AffectsButtons.GetConfiguration()
  local config = {
    BUTTON_FONT = { label = "Button Font", type = "font", value = AB_CONFIGURATION.BUTTON_FONT.name .. " (" .. AB_CONFIGURATION.BUTTON_FONT.size .. ")", raw_value = AB_CONFIGURATION.BUTTON_FONT },
    HEADER_FONT = { label = "Header Font", type = "font", value = AB_CONFIGURATION.HEADER_FONT.name .. " (" .. AB_CONFIGURATION.HEADER_FONT.size .. ")", raw_value = AB_CONFIGURATION.HEADER_FONT },
    WINDOW_WIDTH = { label = "Panel Width", type = "number", value = tostring(AB_CONFIGURATION.WINDOW_WIDTH), raw_value = AB_CONFIGURATION.WINDOW_WIDTH, min = 10, max = 800 },
    HEADER_TEXT = { label = "Header Text", type = "text", value = AB_CONFIGURATION.HEADER_TEXT, raw_value = AB_CONFIGURATION.HEADER_TEXT },
    SHOW_HEADER = { label = "Show Header", type = "bool", value = tostring(AB_CONFIGURATION.SHOW_HEADER), raw_value = AB_CONFIGURATION.SHOW_HEADER },
    LOCK_POSITION = { label = "Lock Position", type = "bool", value = tostring(AB_CONFIGURATION.LOCK_POSITION), raw_value = AB_CONFIGURATION.LOCK_POSITION },
    STRETCH_HEIGHT = { label = "Stretch Height", type = "bool", value = tostring(AB_CONFIGURATION.STRETCH_HEIGHT), raw_value = AB_CONFIGURATION.STRETCH_HEIGHT },
    BACKGROUND_COLOR = { label = "Background Color", type = "color", value = AB_CONFIGURATION.BACKGROUND_COLOR, raw_value = AB_CONFIGURATION.BACKGROUND_COLOR },
    BORDER_COLOR = { label = "Border Color", type = "color", value = AB_CONFIGURATION.BORDER_COLOR, raw_value = AB_CONFIGURATION.BORDER_COLOR },
    NEUTRAL_COLOR = { label = "Neutral Color", type = "color", value = AB_CONFIGURATION.NEUTRAL_COLOR, raw_value = AB_CONFIGURATION.NEUTRAL_COLOR },
    EXPIRED_COLOR = { label = "Uncasted Color", type = "color", value = AB_CONFIGURATION.EXPIRED_COLOR, raw_value = AB_CONFIGURATION.EXPIRED_COLOR },
    CASTED_COLOR = { label = "Casted Color", type = "color", value = AB_CONFIGURATION.CASTED_COLOR, raw_value = AB_CONFIGURATION.CASTED_COLOR },
    EXPIRING_COLOR = { label = "Expiring Color", type = "color", value = AB_CONFIGURATION.EXPIRING_COLOR, raw_value = AB_CONFIGURATION.EXPIRING_COLOR },
    ANCHOR = { label = "Anchor", type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST }
  }

  return config
end

function AffectsButtons.SaveConfiguration(option, config)
  if option == "ANCHOR" then
    _AffectsButtons.adjustAnchor(config.raw_value)
  else
    AB_CONFIGURATION[option] = config.raw_value
  end
  
  AffectsButtons.SaveMiniWindow()
  _AffectsButtons.createWindowAndFont()
  AffectsButtons.DrawMiniWindow()
end

function _AffectsButtons.adjustAnchor(anchor_idx)
  local anchor = ANCHOR_LIST[anchor_idx]:sub(4)
  if anchor == nil or anchor == "" or anchor == "None" then
    return
  elseif anchor == "Top Left (Window)" then 
    WINDOW_LEFT = 0
    WINDOW_TOP = 0
  elseif anchor == "Bottom Left (Window)" then 
    WINDOW_LEFT = 0
    WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)
  elseif anchor == "Top Right (Window)" then
    WINDOW_LEFT = GetInfo(281) - AB_CONFIGURATION.WINDOW_WIDTH
    WINDOW_TOP = 0    
  elseif anchor == "Bottom Right (Window)" then
    WINDOW_LEFT = GetInfo(281) - AB_CONFIGURATION.WINDOW_WIDTH
    WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)    
  elseif anchor == "Top Left (Output)" then
    WINDOW_LEFT = math.max(0, GetInfo(290) - AB_CONFIGURATION.WINDOW_WIDTH)
    WINDOW_TOP = GetInfo(291)    
  elseif anchor == "Bottom Left (Output)" then
    WINDOW_LEFT = math.max(0, GetInfo(290) - AB_CONFIGURATION.WINDOW_WIDTH)
    WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)
  elseif anchor ==  "Top Right (Output)" then
    WINDOW_LEFT = math.min(GetInfo(281) -  AB_CONFIGURATION.WINDOW_WIDTH, GetInfo(292))
    WINDOW_TOP = GetInfo(291)    
  elseif anchor ==  "Bottom Right (Output)" then
    WINDOW_LEFT = math.min(GetInfo(281) -  AB_CONFIGURATION.WINDOW_WIDTH, GetInfo(292))
    WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)    
  end

  --Note("Set anchor points: " .. anchor .. " (" .. BUTTON_X .. ", " .. BUTTON_Y .. ")")

  AffectsButtons.DrawMiniWindow()
end

function _AffectsButtons.loadSavedData()
  local serialized_config = GetVariable(CHARACTER_NAME .. "_affectsbuttons_config") or ""
  if serialized_config == "" then
    AB_CONFIGURATION = {
      BUTTON_FONT = { name = "Trebuchet MS", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 },
      HEADER_FONT = { name = "Trebuchet MS", size = 9, colour = 12632256, bold = 0, italic = 0, underline = 0, strikeout = 0 },
      WINDOW_WIDTH = 150,
      SHOW_HEADER = true,
      LOCK_POSITION = false,
      STRETCH_HEIGHT = false,
      HEADER_TEXT = "~ Affects ~",
      BACKGROUND_COLOR = 0,
      BORDER_COLOR = 12632256,
      NEUTRAL_COLOR = 8421504,
      EXPIRED_COLOR = 255,
      CASTED_COLOR = 32768,
      EXPIRING_COLOR = 65535
    }
  else
    AB_CONFIGURATION = Deserialize(serialized_config)
  end
  
  WINDOW_LEFT = GetVariable(CHARACTER_NAME .. "_affectsbuttons_left") or 0
  WINDOW_TOP = GetVariable(CHARACTER_NAME .. "_affectsbuttons_top") or 0

  local serialized_buttons = GetVariable(CHARACTER_NAME .. "_affectsbuttons_buttons") or ""
  if serialized_buttons == "" then
    BUTTONS = {}
    local old_buttons = GetVariable("affects_buttons")
    if old_buttons ~= nil then
      local convert_old = utils.msgbox("There are no buttons saved for this character, convert the existing buttons from a previous version?", "Convert Buttons?", "yesno", "?")
      if convert_old then
        BUTTONS = Deserialize(old_buttons)
      end
    end
  else
    BUTTONS = Deserialize(serialized_buttons)
  end

  if (#BUTTONS == 0) then
    Note("Looks like you don't have any buttons set up yet.")
    Note("Type 'affects help' to see how to get started.")
  end

  local serialized_durations = GetVariable("affects_durations") or ""
  if serialized_durations == "" then
    DURATIONS = {}
  else
    DURATIONS = Deserialize(serialized_durations)
  end
end

function _AffectsButtons.drawAffect(num, affect, title, command, top_pos)
  local text_width = WindowTextWidth(WIN, BUTTONFONT, title, true)
  local middle_pos = (AB_CONFIGURATION.WINDOW_WIDTH - text_width) / 2
  local expires_in = _AffectsButtons.getExpiration(affect)
  local button_color = _AffectsButtons.getButtonColor(expires_in, affect)
  local tooltip = _AffectsButtons.getTooltip(expires_in) or title
  local max_duration = DURATIONS[affect] or 300
  local current = _AffectsButtons.clamp(expires_in, 0, max_duration)
  local inner_width = AB_CONFIGURATION.WINDOW_WIDTH - 8
  local outer_width = AB_CONFIGURATION.WINDOW_WIDTH - 7
  local bottom_position = top_pos + LINE_HEIGHT

  -- button
  WindowRectOp(WIN, 2, 8, top_pos, inner_width, bottom_position, button_color)
  WindowText(WIN, BUTTONFONT, title, middle_pos, top_pos, 0, 0, AB_CONFIGURATION.BUTTON_FONT.colour, true)
  WindowRectOp(WIN, 1, 7, top_pos, outer_width, bottom_position, AB_CONFIGURATION.BORDER_COLOR)

  -- hotspot
  WindowAddHotspot(WIN, command, 8, top_pos, inner_width - 8, top_pos + 20, "", "", "affectsbuttons_button_mousedown", "affectsbuttons_button_mousedown_cancel", "affectsbuttons_button_mouseup", tooltip, 1, 0)

  -- expiration meter
  gauge(WIN, nil, current, max_duration, 8, top_pos + 20, AB_CONFIGURATION.WINDOW_WIDTH - 16, 8, button_color, AB_CONFIGURATION.BACKGROUND_COLOR, 0, nil, AB_CONFIGURATION.BORDER_COLOR)

  return top_pos + 30
end

function _AffectsButtons.getExpiration(affect)
  if (affect == nil) then
    return nil
  elseif (affect == "") then
    return nil
  elseif (PERM_AFFECTS[affect] == 1) then
    return 666666666
  elseif (CURRENT_AFFECTS[affect] == nil) then
    return 0
  end

  return CURRENT_AFFECTS[affect] - os.time()
end

function _AffectsButtons.getButtonColor(expires_in, affect)
  if (expires_in == nil) then
    return AB_CONFIGURATION.NEUTRAL_COLOR
  elseif (expires_in <= 0) then
    return AB_CONFIGURATION.EXPIRED_COLOR
  elseif (expires_in > 300) then
    return AB_CONFIGURATION.CASTED_COLOR
  end

  return AB_CONFIGURATION.EXPIRING_COLOR
end

function _AffectsButtons.getTooltip(expires_in)
  if (expires_in ~= nil) then
    if (expires_in == 666666666) then
      return "permanent affect"
    elseif (expires_in > 0) then
      local m, s = _AffectsButtons.getTimeFromMinutes(expires_in / 60)
      return m .. " minutes and " .. s .. " seconds.";
    end
  end

  return nil
end

function _AffectsButtons.getTimeFromMinutes(minutes)
  local mins = math.floor(minutes)
  local secs = math.floor((minutes - mins) * 60)
  return mins, secs
end

function _AffectsButtons.clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

function affectsbuttons_button_mousedown(flags, hs_id)
  CURRENT_COMMAND = nil
  if (flags == miniwin.hotspot_got_lh_mouse) then
    CURRENT_COMMAND = hs_id
  end
end

function affectsbuttons_button_mousedown_cancel(flags, hs_id)
  if CURRENT_COMMAND then CURRENT_COMMAND = nil end
end

function affectsbuttons_button_mouseup(flags, hs_id)
  if CURRENT_COMMAND then Execute(CURRENT_COMMAND) end
end

-- maintenance stuff

function AffectsButtons.AddButton(title, affect, command)
  for _, button in ipairs(BUTTONS) do
    if button.title == title then
      Note("A button with that title already exists!")
      return
    end
  end

  BUTTONS[#BUTTONS + 1] = {
    affect = affect,
    title = title,
    action = command
  }

  AffectsButtons.DrawMiniWindow()
  SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
  Note("Button '" .. title .. "' has been added!")
  SaveState()
end

function AffectsButtons.EditButton(title, new_affect, new_command)
  for _, button in ipairs(BUTTONS) do
    if button.title == title then
      button.affect = new_affect
      button.action = new_command

      AffectsButtons.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
      Note("Button '" .. title .. "' has been changed!")
      SaveState()
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

function AffectsButtons.RenameButton(old_name, new_name)
  for _, button in ipairs(BUTTONS) do
    if button.title == old_name then
      button.title = new_name

      AffectsButtons.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))     
      Note("Button '" .. old_name .. "' has been changed to '" .. new_name .. "'")
      SaveState()
      return
    end
  end

  Note("Button '" .. old_name .. "' doesn't exist!")
end

function AffectsButtons.DeleteButton(title)
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      table.remove(BUTTONS, i)
      AffectsButtons.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
      Note("Button '" .. title .. "' has been removed!")
      SaveState()
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

function AffectsButtons.MoveButtonUp(title)
  local index = nil
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      index = i
      break
    end
  end

  if index and index > 1 then
    BUTTONS[index], BUTTONS[index - 1] = BUTTONS[index - 1], BUTTONS[index]
    AffectsButtons.DrawMiniWindow()
    SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
    Note("Button '" .. title .. "' has been moved up!")
    SaveState()
  end
end

function AffectsButtons.MoveButtonDown(title)
  local index = nil
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      index = i
      break
    end
  end

  if index and index < #BUTTONS then
    BUTTONS[index], BUTTONS[index + 1] = BUTTONS[index + 1], BUTTONS[index]
    AffectsButtons.DrawMiniWindow()
    SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
    Note("Button '" .. title .. "' has been moved down!")
    SaveState()
  end
end


function AffectsButtons.ToggleBroadcastAffect(affect)
  if BROADCAST == nil then BROADCAST = {} end
  local broadcasting = BROADCAST[affect] or false
  BROADCAST[affect] = not broadcasting

  if BROADCAST[affect] then Note("Losing and gaining '" .. affect .. "' will be broadcast.") 
  else Note("Losing and gaining '" .. affect .. "' will NOT be broadcast.") end
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

function _AffectsButtons.convertFromBool(bool_value)
  if bool_value then
    return 1
  else
    return 0
  end
end

function _AffectsButtons.convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

function AffectsButtons.GetDuration(affect)
  return DURATIONS[affect]
end

function AffectsButtons._debug()
  AffectsButtons.SetAffect("fake affect", 800, true)
end

return AffectsButtons