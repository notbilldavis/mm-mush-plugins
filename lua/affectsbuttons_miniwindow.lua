require "gauge"

local config_window = require "configuration_miniwindow"
local bad_affects = require("badaffects_miniwindow")

local ABMW = {}
local abmw = {}

local WIN = "affectsbuttons_" .. GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local HEADERFONT = WIN .. "_header_font"

local AB_CONFIGURATION = nil

local LINE_HEIGHT = nil

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

local HAS_ACTIVE_AFFECTS = true
local NEGATIVE_AFFECTS = {}

local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

function ABMW.PrepareMiniWindow()
  local serialized_config = GetVariable("last_affectsbuttons_config")
  if serialized_config ~= nil then
    local temp_config = Deserialize(serialized_config)
    WindowCreate(WIN, temp_config.left, temp_config.top, temp_config.width, temp_config.height, 12, 2, temp_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, temp_config.width, temp_config.height, temp_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, temp_config.border)
    WindowShow(WIN, true)
  end
end

function ABMW.InitializeMiniWindow(character_name)
  CHARACTER_NAME = character_name

  abmw.loadSavedData()
  abmw.createWindowAndFont()
  abmw.initializeNegativeAffects()

  INIT = true

  ABMW.DrawMiniWindow()
  bad_affects.InitializeMiniWindow(character_name)
end

function abmw.createWindowAndFont()
  local btnfont = AB_CONFIGURATION["BUTTON_FONT"]
  local hdrfont = AB_CONFIGURATION["HEADER_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)

  WindowFont(WIN, BUTTONFONT, btnfont.name, btnfont.size, 
    abmw.convertToBool(btnfont.bold), 
    abmw.convertToBool(btnfont.italic), 
    abmw.convertToBool(btnfont.italic), 
    abmw.convertToBool(btnfont.strikeout))

  WindowFont(WIN, HEADERFONT, hdrfont.name, hdrfont.size, 
    abmw.convertToBool(hdrfont.bold), 
    abmw.convertToBool(hdrfont.italic), 
    abmw.convertToBool(hdrfont.italic), 
    abmw.convertToBool(hdrfont.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1)

  WINDOW_LEFT = WINDOW_LEFT or WindowInfo(WIN, 1)
  WINDOW_TOP = WINDOW_TOP or WindowInfo(WIN, 2)
end

function abmw.initializeNegativeAffects()
  local bad = { "blindness", "confusion", "deafen", "etheric pollution",
    "hinder", "mental disruption", "web", "pestilence", "silence", "sleep", 
    "slow magic", "slow", "stone curse", "paralysis", "extinction", "amnesia",
    "energy orb", "plague", "poison", "memory drain", "binding curse", "curse",
    "finality of the ender", "gangrene", "malignancy", "hex", "blue cough disease",
    "subdue", "condemn", "traumatize", "insanity", "with swiveling hooks",
    "jinx", "hobble", "bleeding", "disjunction", "decrepify", "vacuum web",
    "poverty of maradas", "pressure points", "unraveling", "dull wits",
    "withering touch", "scarify", "dampening field", "malediction", "paralyze",
    "impede movement", "strike of death", "poverty of ether", "immobilize",
    "damnation", "spider incubator", "entomb", "contagion", "faerie fire",
    "giant grasping hand", "existential horror", "slurping proboscis",
    "harrow", "excommunicate", "boreworms disease", "irk", "nightmares",
    "hotfoot", "burning ember", "cavern sickness disease", "mesmerize",
    "fatigue", "ash evocation", "evil eye", "hellfire surge", "latent charge",
    "static field", "weaken", "dead air", "light lungs disease" }

  for _, aff in ipairs(bad) do
    NEGATIVE_AFFECTS[aff] = true
  end
end

function ABMW.DrawMiniWindow()
  if not INIT then return end

  WindowShow(WIN, false)

  local height = (#BUTTONS * 30) + 10
  if AB_CONFIGURATION.SHOW_HEADER then height = height + 30 end
  if AB_CONFIGURATION.STRETCH_HEIGHT then height = GetInfo(280) end

  WindowPosition(WIN, WINDOW_LEFT, WINDOW_TOP, 4, 2)
  WindowResize(WIN, AB_CONFIGURATION.WINDOW_WIDTH, height - 2, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, AB_CONFIGURATION.WINDOW_WIDTH, height, AB_CONFIGURATION.BACKGROUND_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, AB_CONFIGURATION.BORDER_COLOR)

  local top_pos = 6
  if AB_CONFIGURATION.SHOW_HEADER then
    top_pos = abmw.drawHeader(AB_CONFIGURATION.HEADER_TEXT, top_pos, true)
  end 

  if AB_CONFIGURATION.SHOW_CAST_FAVORITES then
    top_pos = abmw.drawAffect(nil, AB_CONFIGURATION.CAST_FAVORITES_LABEL, "affects cast favorites", top_pos, false)
  end

  HAS_ACTIVE_AFFECTS = false
  for _, v in ipairs(BUTTONS) do
    if abmw.isEmptyButton(v) and AB_CONFIGURATION.SHOW_EMPTY_AS_HEADER then
      top_pos = abmw.drawHeader(v["title"], top_pos, false)
    else
      top_pos = abmw.drawAffect(v["affect"], v["title"], v["action"], top_pos, v["favorite"] or false)
    end
  end

  if not HAS_ACTIVE_AFFECTS then
    EnableTimer("affects_timer", false)
  elseif AB_CONFIGURATION.REFRESH_TIME > 0 then
    EnableTimer("affects_timer", true)
  end

  abmw.handleBadAffects()

  WindowShow(WIN, true)
end

function abmw.isEmptyButton(btn)
  local aff = btn["affect"] or ""
  local act = btn["action"] or ""
  return aff == "" and act == ""
end

function abmw.handleBadAffects()
  bad_affects.ClearMiniWindow()
  for aff, expire in pairs(CURRENT_AFFECTS) do
    if NEGATIVE_AFFECTS[aff] then
      bad_affects.AddNegativeAffect(aff, expire, false)
    end
  end
  bad_affects.DrawMiniWindow()
end

function affectsbuttons_drag_mousedown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)

  if (flags == miniwin.hotspot_got_rh_mouse) then
    local menu_items = "Add Button | Hide Header | "
    if AB_CONFIGURATION.LOCK_POSITION then menu_items = menu_items .. "+" end
    menu_items = menu_items .. "Lock Position | >Anchor | "
    for _, a in ipairs(ANCHOR_LIST) do
      menu_items = menu_items .. a .. " | "
    end
    menu_items = menu_items .. " < | - | Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Add Button" then
      ABMW.AddButton(nil, nil, nil)
    elseif result == "Hide Header" then
      AB_CONFIGURATION.SHOW_HEADER = false
    elseif result == "Lock Position" then
      AB_CONFIGURATION.LOCK_POSITION = not AB_CONFIGURATION.LOCK_POSITION    
    elseif result == "Configure" then
      abmw.configure()
    else
      for i, a in ipairs(ANCHOR_LIST) do
        if result == a then
          abmw.adjustAnchor(i)
        end
      end
    end
    ABMW.SaveMiniWindow()
    ABMW.DrawMiniWindow()
  end
end

function affectsbuttons_drag_move(flags, hotspot_id)
  local pos_x = abmw.clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - AB_CONFIGURATION.WINDOW_WIDTH)
  local pos_y = abmw.clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function affectsbuttons_drag_release(flags, hotspot_id)
  WINDOW_LEFT = WindowInfo(WIN, 10)
  WINDOW_TOP = WindowInfo(WIN, 11)
  Repaint()
  SetVariable(CHARACTER_NAME .. "_affectsbuttons_left", WINDOW_LEFT)
  SetVariable(CHARACTER_NAME .. "_affectsbuttons_top", WINDOW_TOP)
end

function ABMW.ClearMiniWindow()
  local possible_wolf = CURRENT_AFFECTS["wolf_familiar"]
  CURRENT_AFFECTS = {}
  PERM_AFFECTS = {}
  if possible_wolf ~= nil then
    CURRENT_AFFECTS["wolf_familiar"] = possible_wolf
  end
end

function ABMW.CloseMiniWindow()
  ABMW.SaveMiniWindow()
  bad_affects.CloseMiniWindow()
  WindowShow(WIN, false)
end

function ABMW.SaveMiniWindow()
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
  SetVariable(CHARACTER_NAME .. "_affectsbuttons_broadcast", Serialize(BROADCAST))
  
  bad_affects.SaveMiniWindow()
end

function ABMW.SetAffect(affect, time, notify, refresh)
  if (time == 0) then
    ABMW.RemoveAffect(affect, notify)
  else
    if time == -1 then
      PERM_AFFECTS[affect] = 1
    else
      if AB_CONFIGURATION.REFRESH_TIME > 0 then
        EnableTimer("affects_timer", true)
      end
      local previous_temp = CURRENT_AFFECTS[affect] or 0
      CURRENT_AFFECTS[affect] = os.time() + (time / 4 * 60)

      abmw.checkDuration(affect)
      abmw.checkForNotifyAdd(notify, affect, previous_temp)

      if NEGATIVE_AFFECTS[affect] then
        bad_affects.AddNegativeAffect(affect, CURRENT_AFFECTS[affect], true)
      end
    end

    if refresh == nil or refresh == true then
      ABMW.DrawMiniWindow()
    end
  end
end

function ABMW.RemoveAffect(affect, notify, refresh)
  local previous_temp = CURRENT_AFFECTS[affect] or 0

  CURRENT_AFFECTS[affect] = 0
  PERM_AFFECTS[affect] = 0

  abmw.checkForNotifyRemove(notify, affect, previous_temp)

  if NEGATIVE_AFFECTS[affect] then
    bad_affects.RemoveNegativeAffect(affect, true)
  end

  if refresh == nil or refresh == true then
    ABMW.DrawMiniWindow()
  end
end

function abmw.checkDuration(affect)
  local expires_in = CURRENT_AFFECTS[affect] - os.time()
  if DURATIONS[affect] == nil or DURATIONS[affect] < expires_in then
    DURATIONS[affect] = expires_in
    SetVariable("affects_durations", Serialize(DURATIONS))
    SaveState()
  end
end

function abmw.checkForNotifyAdd(notify, affect, highest_prev)
  if notify and highest_prev == 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU GAINED " .. affect:upper() .. " !!!")
  end
end

function abmw.checkForNotifyRemove(notify, affect, highest_prev)
  if notify and highest_prev > 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU LOST " .. affect:upper() .. " !!!")
  end
end

function ABMW.GetConfiguration()
  local config = {
    Button_Options = abmw.getButtonsConfiguration(),
    Negative_Affects_Options = bad_affects.GetConfiguration()
  }

  return config
end

function abmw.getButtonsConfiguration()
  local config = {
    BUTTON_FONT = { label = "Button Font", type = "font", value = AB_CONFIGURATION.BUTTON_FONT.name .. " (" .. AB_CONFIGURATION.BUTTON_FONT.size .. ")", raw_value = AB_CONFIGURATION.BUTTON_FONT },
    HEADER_FONT = { label = "Header Font", type = "font", value = AB_CONFIGURATION.HEADER_FONT.name .. " (" .. AB_CONFIGURATION.HEADER_FONT.size .. ")", raw_value = AB_CONFIGURATION.HEADER_FONT },
    BUTTON_HEIGHT = { label = "Button Height", type = "number", value = tostring(AB_CONFIGURATION.BUTTON_HEIGHT), raw_value = AB_CONFIGURATION.BUTTON_HEIGHT, min = 5, max = 200 },
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
    FAVORITE_BORDER = { label = "Favorite Border Color", type = "color", value = AB_CONFIGURATION.FAVORITE_BORDER, raw_value = AB_CONFIGURATION.FAVORITE_BORDER },
    FAVORITE_COLOR = { label = "Favorite Color", type = "color", value = AB_CONFIGURATION.FAVORITE_COLOR, raw_value = AB_CONFIGURATION.FAVORITE_COLOR },
    SHOW_CAST_FAVORITES = { label = "Show Cast Favorites", type = "bool", value = tostring(AB_CONFIGURATION.SHOW_CAST_FAVORITES), raw_value = AB_CONFIGURATION.SHOW_CAST_FAVORITES },
    CAST_FAVORITES_LABEL = { label = "Cast Favorites Label", type = "text", value = AB_CONFIGURATION.CAST_FAVORITES_LABEL, raw_value = AB_CONFIGURATION.CAST_FAVORITES_LABEL},
    ANCHOR = { label = "Anchor", type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST },
    REFRESH_TIME = { label = "Refresh Time (seconds)", type = "number", raw_value = AB_CONFIGURATION.REFRESH_TIME, min = 0, max = 1000 },
    SHOW_EMPTY_AS_HEADER = { label = "Empty Buttons as Headers", type = "bool", raw_value = AB_CONFIGURATION.SHOW_EMPTY_AS_HEADER },
  }

  return config
end

function ABMW.SaveConfiguration(group_id, option_id, config)
  if group_id == "Button_Options" then
    abmw.saveButtonsConfiguration(option_id, config)
  elseif group_id == "Negative_Affects_Options" then
    bad_affects.SaveConfiguration(option_id, config)
  end
end

function abmw.saveButtonsConfiguration(option, config)
  if option == "ANCHOR" then
    abmw.adjustAnchor(config.raw_value)
  else
    AB_CONFIGURATION[option] = config.raw_value

    if option == "REFRESH_TIME" then
      if AB_CONFIGURATION.REFRESH_TIME > 0 then
        SetTimerOption ("affects_timer", "second", AB_CONFIGURATION.REFRESH_TIME)
        EnableTimer("affects_timer", true)
      else
        Note("Refresh time has been set to zero, affect expirations will not update automatically.")
        EnableTimer("affects_timer", false)
      end
    end
  end
  
  ABMW.SaveMiniWindow()
  abmw.createWindowAndFont()
  ABMW.DrawMiniWindow()
end

function abmw.adjustAnchor(anchor_idx)
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

  ABMW.DrawMiniWindow()
end

function abmw.loadSavedData()
  local serialized_config = GetVariable(CHARACTER_NAME .. "_affectsbuttons_config") or ""
  if serialized_config == "" then
    AB_CONFIGURATION = {}
  else
    AB_CONFIGURATION = Deserialize(serialized_config)
  end

  AB_CONFIGURATION.BUTTON_FONT = abmw.getValueOrDefault(AB_CONFIGURATION.BUTTON_FONT, { name = "Trebuchet MS", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  AB_CONFIGURATION.HEADER_FONT = abmw.getValueOrDefault(AB_CONFIGURATION.HEADER_FONT, { name = "Trebuchet MS", size = 9, colour = 12632256, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  AB_CONFIGURATION.BUTTON_HEIGHT = abmw.getValueOrDefault(AB_CONFIGURATION.BUTTON_HEIGHT, 25)
  AB_CONFIGURATION.WINDOW_WIDTH = abmw.getValueOrDefault(AB_CONFIGURATION.WINDOW_WIDTH, 150)
  AB_CONFIGURATION.SHOW_HEADER = abmw.getValueOrDefault(AB_CONFIGURATION.SHOW_HEADER, true)
  AB_CONFIGURATION.LOCK_POSITION = abmw.getValueOrDefault(AB_CONFIGURATION.LOCK_POSITION, false)
  AB_CONFIGURATION.STRETCH_HEIGHT = abmw.getValueOrDefault(AB_CONFIGURATION.STRETCH_HEIGHT, false)
  AB_CONFIGURATION.HEADER_TEXT = abmw.getValueOrDefault(AB_CONFIGURATION.HEADER_TEXT, "~ Affects ~")
  AB_CONFIGURATION.BACKGROUND_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.BACKGROUND_COLOR, 0)
  AB_CONFIGURATION.BORDER_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.BORDER_COLOR, 12632256)
  AB_CONFIGURATION.NEUTRAL_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.NEUTRAL_COLOR, 8421504)
  AB_CONFIGURATION.EXPIRED_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.EXPIRED_COLOR, 255)
  AB_CONFIGURATION.CASTED_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.CASTED_COLOR, 32768)
  AB_CONFIGURATION.EXPIRING_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.EXPIRING_COLOR, 65535)
  AB_CONFIGURATION.FAVORITE_BORDER = abmw.getValueOrDefault(AB_CONFIGURATION.FAVORITE_BORDER, ColourNameToRGB("black"))
  AB_CONFIGURATION.FAVORITE_COLOR = abmw.getValueOrDefault(AB_CONFIGURATION.FAVORITE_COLOR, ColourNameToRGB("gold"))
  AB_CONFIGURATION.SHOW_CAST_FAVORITES = abmw.getValueOrDefault(AB_CONFIGURATION.SHOW_CAST_FAVORITES, true)
  AB_CONFIGURATION.CAST_FAVORITES_LABEL = abmw.getValueOrDefault(AB_CONFIGURATION.CAST_FAVORITES_LABEL, "All Favorites")
  AB_CONFIGURATION.REFRESH_TIME = abmw.getValueOrDefault(AB_CONFIGURATION.REFRESH_TIME, 10)
  AB_CONFIGURATION.SHOW_EMPTY_AS_HEADER = abmw.getValueOrDefault(AB_CONFIGURATION.SHOW_EMPTY_AS_HEADER, true)

  if AB_CONFIGURATION.REFRESH_TIME > 0 then
    SetTimerOption ("affects_timer", "second", AB_CONFIGURATION.REFRESH_TIME)
    EnableTimer("affects_timer", true)
  else
    EnableTimer("affects_timer", false)
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

  local serialized_broadcasts = GetVariable(CHARACTER_NAME .. "_affectsbuttons_broadcast") or ""
  if serialized_broadcasts == "" then
    BROADCAST = { sanctuary = true }
  else
    BROADCAST = Deserialize(serialized_broadcasts)
  end
end

function abmw.drawHeader(header_text, y_pos, is_main_header)
  local text_width = math.min(AB_CONFIGURATION.WINDOW_WIDTH, WindowTextWidth(WIN, HEADERFONT, header_text, true))
  local center_pos_x = (AB_CONFIGURATION.WINDOW_WIDTH - text_width) / 2
  WindowText(WIN, HEADERFONT, header_text, center_pos_x, y_pos, 0, 0, AB_CONFIGURATION.HEADER_FONT.colour, false)

  if is_main_header then
    if not AB_CONFIGURATION.LOCK_POSITION then
      WindowAddHotspot(WIN, "drag_" .. WIN, 0, 0, AB_CONFIGURATION.WINDOW_WIDTH, 30, "", "", "affectsbuttons_drag_mousedown", "", "", "", 10, 0)
      WindowDragHandler (WIN, "drag_" .. WIN, "affectsbuttons_drag_move", "affectsbuttons_drag_release", 0)
    else
      WindowAddHotspot(WIN, "drag_" .. WIN, 0, 0, AB_CONFIGURATION.WINDOW_WIDTH, 30, "", "", "affectsbuttons_drag_mousedown", "", "", "", 0, 0)
    end
  else
    WindowAddHotspot(WIN, header_text .. "~~", 8, y_pos, AB_CONFIGURATION.WINDOW_WIDTH, y_pos + AB_CONFIGURATION.BUTTON_HEIGHT, "", "", 
      "affectsbuttons_button_mousedown", "affectsbuttons_button_mousedown_cancel", "affectsbuttons_button_mouseup", "", 0, 0)
  end

  return y_pos + 25
end

function abmw.drawAffect(affect, title, command, top_pos, favorite)
  local text_width = WindowTextWidth(WIN, BUTTONFONT, title, true)
  local middle_pos = (AB_CONFIGURATION.WINDOW_WIDTH - text_width) / 2
  local expires_in = abmw.getExpiration(affect)
  local button_color = abmw.getButtonColor(expires_in)
  local tooltip = abmw.getTooltip(expires_in) or title
  local max_duration = DURATIONS[affect] or 300
  local current = abmw.clamp(expires_in, 0, max_duration)
  local inner_width = AB_CONFIGURATION.WINDOW_WIDTH - 8
  local outer_width = AB_CONFIGURATION.WINDOW_WIDTH - 7
  local bottom_position = top_pos + (AB_CONFIGURATION.BUTTON_HEIGHT or LINE_HEIGHT)
  local middle_y = top_pos + (AB_CONFIGURATION.BUTTON_HEIGHT - LINE_HEIGHT) / 2

  if expires_in ~= nil and expires_in > 0 and expires_in ~= 666666666 then
    HAS_ACTIVE_AFFECTS = true
  end

  -- button
  WindowRectOp(WIN, 2, 8, top_pos, inner_width, bottom_position, button_color)

  if favorite then 
    local star_size = (AB_CONFIGURATION.BUTTON_HEIGHT - 12) * .75
    local star_points = createFavoriteStar(star_size, outer_width - star_size * 2, top_pos + AB_CONFIGURATION.BUTTON_HEIGHT / 2)
    WindowPolygon(WIN, star_points, AB_CONFIGURATION.FAVORITE_BORDER, miniwin.pen_solid, 1, AB_CONFIGURATION.FAVORITE_COLOR, miniwin.brush_solid, true)
  end

  WindowText(WIN, BUTTONFONT, title, middle_pos, middle_y, 0, 0, AB_CONFIGURATION.BUTTON_FONT.colour, true)
  WindowRectOp(WIN, 1, 7, top_pos, outer_width, bottom_position, AB_CONFIGURATION.BORDER_COLOR)

  -- hotspot
  WindowAddHotspot(WIN, title .. "~" .. command .. "~" .. (affect or ""), 8, top_pos, inner_width, top_pos + AB_CONFIGURATION.BUTTON_HEIGHT, "", "", "affectsbuttons_button_mousedown", "affectsbuttons_button_mousedown_cancel", "affectsbuttons_button_mouseup", tooltip, 1, 0)

  -- expiration meter
  gauge(WIN, nil, current, max_duration, 8, top_pos + AB_CONFIGURATION.BUTTON_HEIGHT, AB_CONFIGURATION.WINDOW_WIDTH - 16, 8, button_color, AB_CONFIGURATION.BACKGROUND_COLOR, 0, nil, AB_CONFIGURATION.BORDER_COLOR)

  return top_pos + AB_CONFIGURATION.BUTTON_HEIGHT + 12
end

function createFavoriteStar(size, offsetX, offsetY)
   local points = {}
  local outer_radius = size
  local inner_radius = math.floor(size * 0.5 + 0.5)

  local angle_step = math.pi / 5 
  local angle = -math.pi / 2

  local first_x, first_y = nil, nil

  for i = 1, 10 do
    local radius = (i % 2 == 1) and outer_radius or inner_radius
    local x = math.floor(offsetX + math.cos(angle) * radius + 0.5)
    local y = math.floor(offsetY + math.sin(angle) * radius + 0.5)

    if i == 1 then
        first_x, first_y = x, y
    end

    table.insert(points, string.format("%d,%d", x, y))
    angle = angle + angle_step
  end

  table.insert(points, string.format("%d,%d", first_x, first_y))

  return table.concat(points, ",")
end

function abmw.getExpiration(affect)
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

function abmw.getButtonColor(expires_in)
  if (expires_in == nil) then
    return AB_CONFIGURATION.NEUTRAL_COLOR
  elseif (expires_in <= 0) then
    return AB_CONFIGURATION.EXPIRED_COLOR
  elseif (expires_in > 300) then
    return AB_CONFIGURATION.CASTED_COLOR
  end

  return AB_CONFIGURATION.EXPIRING_COLOR
end

function abmw.getTooltip(expires_in)
  if (expires_in ~= nil) then
    if (expires_in == 666666666) then
      return "permanent affect"
    elseif (expires_in > 0) then
      local m, s = abmw.getTimeFromMinutes(expires_in / 60)
      return m .. " minutes and " .. s .. " seconds.";
    end
  end

  return nil
end

function abmw.getTimeFromMinutes(minutes)
  local mins = math.floor(minutes)
  local secs = math.floor((minutes - mins) * 60)
  return mins, secs
end

function abmw.clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

function affectsbuttons_button_mousedown(flags, hs_id)
  CURRENT_COMMAND = nil
  if (flags == miniwin.hotspot_got_lh_mouse) then
    local split = utils.split(hs_id, "~")
    CURRENT_COMMAND = split[2]
  end
end

function affectsbuttons_button_mousedown_cancel(flags, hs_id)
  if CURRENT_COMMAND then CURRENT_COMMAND = nil end
end

function affectsbuttons_button_mouseup(flags, hs_id)
  if CURRENT_COMMAND then Execute(CURRENT_COMMAND) end
  if (flags == miniwin.hotspot_got_rh_mouse) then
    local split = utils.split(hs_id, "~")
    if split[1] == "All Favorites" then
      local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), "Configure")
      if result == "Configure" then
        abmw.configure()
      end
    else
      local menu_items = "Edit | Delete | Move Up | Move Down | - | Add Button | Configure"
      if CURRENT_AFFECTS[split[3]] ~= nil and CURRENT_AFFECTS[split[3]] > os.time() then
        menu_items = "Clear | - | " .. menu_items
      end
      if split[2] ~= "" or split[3] ~= "" then
        menu_items = "Set Favorite | " .. menu_items
      end
      local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
      if result == nil or result == "" then return end
      if result == "Clear" then
        Send("affects clear '" .. CURRENT_AFFECTS[split[3]] .. "'")
      elseif result == "Edit" then
        ABMW.EditButton(split[1], nil, nil)
      elseif result == "Delete" then
        ABMW.DeleteButton(split[1])
      elseif result == "Move Up" then
        ABMW.MoveButtonUp(split[1])
      elseif result == "Move Down" then
        ABMW.MoveButtonDown(split[1])
      elseif result == "Add Button" then
        ABMW.AddButton(nil, nil, nil)
      elseif result == "Configure" then
        abmw.configure()
      elseif result == "Set Favorite" then
        ABMW.SetFavorite(split[1])
      end
    end
  end
end

function ABMW.CastFavorites()
  local at_least_one = false
  local count = 0
  for _, button in ipairs(BUTTONS) do
    if button.favorite then
      at_least_one = true
      local expires_in = abmw.getExpiration(button.affect)
      
      local button_color = abmw.getButtonColor(expires_in)
      
      if button_color == AB_CONFIGURATION.EXPIRED_COLOR or 
         button_color == AB_CONFIGURATION.EXPIRING_COLOR or 
         button_color == AB_CONFIGURATION.NEUTRAL_COLOR then
        count = count + 1
        Send(button.action)
      end
    end
  end
  if count == 0 then
    if at_least_one then Note("No favorites needed to be casted right now!")
    else Note("No favorites have been set up yet!")
    end
  end
end

-- maintenance stuff

function ABMW.AddButton(title, affect, command)
  if title == nil or title == "" then
    title = utils.inputbox("Enter a title for the new button.", "Button Title")
    if title == nil or title == "" then return end
  end

  for _, button in ipairs(BUTTONS) do
    if button.title == title or title == "All Favorites" then
      Note("A button with that title already exists!")
      return
    end
  end

  if affect == nil then
    affect = utils.inputbox("The affect this button should represent and track. (optional)", "Button Affect")
  end

  if command == nil then
    command = utils.inputbox("The command this button should perform when clicked. (optional)", "Button Command")
  end
  
  BUTTONS[#BUTTONS + 1] = {
    affect = affect,
    title = title,
    action = command
  }

  ABMW.DrawMiniWindow()
  SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
  Note("Button '" .. title .. "' has been added!")
  SaveState()
end

function ABMW.EditButton(title, new_affect, new_command)
  if title == nil or title:lower() == "all favorites" then return end

  for _, button in ipairs(BUTTONS) do
    if button.title == title then
      if new_affect == nil and new_command == nil then
        local new_title = utils.inputbox("Do you want to rename this button?", "Button Rename", title)
        if new_title ~= nil and new_title ~= "" and new_title ~= title then
          button.title = new_title
        end
      end

      if new_affect == nil then
        new_affect = utils.inputbox("The affect this button should represent and track. (optional)", "Button Affect", button.affect or "")
      end

      if new_command == nil then
        new_command = utils.inputbox("The command this button should perform when clicked. (optional)", "Button Command", button.command or "")
      end

      button.affect = new_affect
      button.action = new_command

      ABMW.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
      if title ~= button.title then title = button.title .. " (formerly '" .. title .. "')" end
      Note("Button '" .. title .. "' has been changed!")
      SaveState()
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

function ABMW.RenameButton(old_name, new_name)
  if old_name:lower() == "all favorites" or new_name:lower() == "all favorites" then return end
  for _, button in ipairs(BUTTONS) do
    if button.title == old_name then
      if new_name == nil or new_name == "" then
        new_name = utils.inputbox("Choose a new name.", "Button Rename", old_name)
        if new_name == nil or new_name == "" or new_name == old_name then
          return
        end
      end

      button.title = new_name

      ABMW.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))     
      Note("Button '" .. old_name .. "' has been changed to '" .. new_name .. "'")
      SaveState()
      return
    end
  end

  Note("Button '" .. old_name .. "' doesn't exist!")
end

function ABMW.DeleteButton(title)
  if title:lower() == "all favorites" then return end
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      table.remove(BUTTONS, i)
      ABMW.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
      Note("Button '" .. title .. "' has been removed!")
      SaveState()
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

function ABMW.MoveButtonUp(title)
  if title:lower() == "all favorites" then return end
  local index = nil
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      index = i
      break
    end
  end

  if index and index > 1 then
    BUTTONS[index], BUTTONS[index - 1] = BUTTONS[index - 1], BUTTONS[index]
    ABMW.DrawMiniWindow()
    SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
    Note("Button '" .. title .. "' has been moved up!")
    SaveState()
  end
end

function ABMW.MoveButtonDown(title)
  if title:lower() == "all favorites" then return end
  local index = nil
  for i, button in ipairs(BUTTONS) do
    if button.title == title then
      index = i
      break
    end
  end

  if index and index < #BUTTONS then
    BUTTONS[index], BUTTONS[index + 1] = BUTTONS[index + 1], BUTTONS[index]
    ABMW.DrawMiniWindow()
    SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
    Note("Button '" .. title .. "' has been moved down!")
    SaveState()
  end
end

function ABMW.SetFavorite(title)
  if title == nil or title:lower() == "all favorites" then return end

  for _, button in ipairs(BUTTONS) do
    if button.title == title then
      button.favorite = not button.favorite

      ABMW.DrawMiniWindow()
      SetVariable(CHARACTER_NAME .. "_affects_buttons", Serialize(BUTTONS))
      if button.favorite then
        Note("Button '" .. title .. "' has been set as a favorite!")
      else
        Note("Button '" .. title .. "' has been removed as a favorite.")
      end
      
      SaveState()
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

function ABMW.ToggleBroadcastAffect(affect)
  if BROADCAST == nil then BROADCAST = {} end
  if affect == nil then return end
  local broadcasting = BROADCAST[affect] or false
  BROADCAST[affect] = not broadcasting

  if BROADCAST[affect] then Note("Losing and gaining '" .. affect .. "' will be broadcast.") 
  else Note("Losing and gaining '" .. affect .. "' will NOT be broadcast.") end

  ABMW.SaveMiniWindow()
end

function abmw.configure()
  config_window.Show({ Button_Options = abmw.getButtonsConfiguration()}, abmw.configureDone)
end

function abmw.configureDone(group_id, option_id, config)
  abmw.saveButtonsConfiguration(option_id, config)
end

function ABMW.ShowBroadcasts()
  if BROADCAST == nil then BROADCAST = {} end
  local broadcasts = {}
  for aff, broadcasting in pairs(BROADCAST) do
    if broadcasting then
      table.insert(broadcasts, aff)
    end
  end
  if #broadcasts == 0 then 
    Note("You are not broadcasting any affects. Use 'affects broadcast <affect>' to add one.")
  else 
    Tell("You are broadcasting the following affects: ")
    ColourNote("white", "black", table.concat(broadcasts, ", "))
    Note("Use 'affects broadcast <affect>' to add more.")
  end  
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

function abmw.convertFromBool(bool_value)
  if bool_value then
    return 1
  else
    return 0
  end
end

function abmw.convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

function ABMW.GetDuration(affect)
  return DURATIONS[affect]
end

function abmw.getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
end

function ABMW._debug()
  bad_affects._debug()
end

return ABMW