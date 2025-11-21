local serializer_installed, serialization_helper = pcall(require, "serializationhelper")
local config_installed, config_window = pcall(require, "configuration_miniwindow")
local const_installed, consts = pcall(require, "consthelper")

local initialize, clear, close, save, getConfiguration, onConfigureDone, setAffect, removeAffect
local load, create, draw, setSizeAndPositionToContent, drawToggleButton, drawAffectsWindows,
  drawAffectsText, adjustAnchor, getFriendlyExpire

local WIN = "badaffects_" .. GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local AFFECTSFONT = WIN .. "_affects_font"

local CONFIG = nil
local POSITION = nil

local CHARACTER_NAME = ""

local TEXT_BUFFER = {}
local BAD_STUFF = {}

local CURRENT_BUTTON_COLOR
local CURRENT_LABEL_COLOR 

local LINE_HEIGHT = nil
local COL_1_WIDTH = 0
local COL_2_WIDTH = 0
local DRAG_X = nil
local DRAG_Y = nil
local EXPANDED = true
local NEGATIVE_AFFECTS = nil

local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

local EXPAND_DIRECTION_LIST = { "Up/Left", "Up/Right", "Down/Left", "Down/Right" }

local SERIALIZE_TAGS = { CONFIG = "_badaffects_config", POSITION = "_badaffects_position" }

initialize = function(character_name)
  CHARACTER_NAME = character_name

  load()
  create()  
  draw()
end

load = function()
  CONFIG = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG)
  POSITION = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION)
 
  CONFIG.BUTTON_FONT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_FONT,  { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.AFFECTS_FONT = serialization_helper.GetValueOrDefault(CONFIG.AFFECTS_FONT,  { name = "Lucida Console", size = 9, colour = 255, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BUTTON_WIDTH = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_WIDTH,  100)
  CONFIG.BUTTON_HEIGHT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_HEIGHT, 25)
  CONFIG.LOCK_POSITION = serialization_helper.GetValueOrDefault(CONFIG.LOCK_POSITION, false)
  CONFIG.EXPAND_DOWN = serialization_helper.GetValueOrDefault(CONFIG.EXPAND_DOWN,  false)
  CONFIG.EXPAND_RIGHT = serialization_helper.GetValueOrDefault(CONFIG.EXPAND_RIGHT,  false)
  CONFIG.ENABLED = serialization_helper.GetValueOrDefault(CONFIG.ENABLED,  true)
  CONFIG.BACKGROUND_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BACKGROUND_COLOR,  0)
  CONFIG.BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BORDER_COLOR,  12632256)
  CONFIG.BUTTON_LABEL = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_LABEL,  "Affects")
  CONFIG.ACTIVE_BUTTON_COLOR = serialization_helper.GetValueOrDefault(CONFIG.ACTIVE_BUTTON_COLOR,  8421504)
  CONFIG.ACTIVE_LABEL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.ACTIVE_LABEL_COLOR,  16777215)
  CONFIG.DISABLED_BUTTON_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DISABLED_BUTTON_COLOR,  6908265)
  CONFIG.DISABLED_LABEL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DISABLED_LABEL_COLOR,  8421504)
  CONFIG.EXTRA_AFFECTS = serialization_helper.GetValueOrDefault(CONFIG.EXTRA_AFFECTS, {})

  POSITION.WINDOW_LEFT = serialization_helper.GetValueOrDefault(POSITION.WINDOW_LEFT, consts.GetOutputRight() - CONFIG.BUTTON_WIDTH - 10)
  POSITION.WINDOW_TOP = serialization_helper.GetValueOrDefault(POSITION.WINDOW_TOP, consts.GetOutputBottom() - CONFIG.BUTTON_HEIGHT - 10)
  POSITION.Z_POSITION = serialization_helper.GetValueOrDefault(POSITION.Z_POSITION, 1000)

  if NEGATIVE_AFFECTS == nil then
    local bad = { "blindness", "confusion", "deafen", "etheric pollution", "hinder", "mental disruption", "web", "pestilence", "silence", "sleep", 
      "slow magic", "slow", "stone curse", "paralysis", "extinction", "amnesia", "energy orb", "plague", "poison", "memory drain", "binding curse", 
      "curse", "finality of the ender", "gangrene", "malignancy", "hex", "blue cough disease", "subdue", "condemn", "traumatize", "insanity", 
      "with swiveling hooks", "jinx", "hobble", "bleeding", "disjunction", "decrepify", "vacuum web", "poverty of maradas", "pressure points", 
      "unraveling", "dull wits", "withering touch", "scarify", "dampening field", "malediction", "paralyze", "impede movement", "strike of death", 
      "poverty of ether", "immobilize", "damnation", "spider incubator", "entomb", "contagion", "faerie fire", "giant grasping hand", "existential horror", 
      "slurping proboscis", "harrow", "excommunicate", "boreworms disease", "irk", "nightmares", "hotfoot", "burning ember", "cavern sickness disease", 
      "mesmerize", "fatigue", "ash evocation", "evil eye", "hellfire surge", "latent charge", "static field", "weaken", "dead air", "light lungs disease", 
      "earworm", "poverty of gems", "poverty of ithrilis", "poverty of dira", "poverty of gath", "lunar eclipse", "plodding fugue", "smoke evocation",
      "soothing nocturne"
    }
    NEGATIVE_AFFECTS = {}
    for _, aff in ipairs(bad) do
      NEGATIVE_AFFECTS[aff] = true
    end
  end
end

create = function()
  if CONFIG == nil then return end

  local btnfont = CONFIG["BUTTON_FONT"]
  local afffont = CONFIG["AFFECTS_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, BUTTONFONT, btnfont.name, btnfont.size, 
    serialization_helper.ConvertToBool(btnfont.bold), 
    serialization_helper.ConvertToBool(btnfont.italic), 
    serialization_helper.ConvertToBool(btnfont.underline), 
    serialization_helper.ConvertToBool(btnfont.strikeout))

  WindowFont(WIN, AFFECTSFONT, afffont.name, afffont.size, 
    serialization_helper.ConvertToBool(afffont.bold), 
    serialization_helper.ConvertToBool(afffont.italic), 
    serialization_helper.ConvertToBool(afffont.underline), 
    serialization_helper.ConvertToBool(afffont.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1) - WindowFontInfo(WIN, BUTTONFONT, 4) + 2
end

draw = function()
  if CONFIG ~= nil and CONFIG.ENABLED and WIN then
    WindowShow(WIN, false)

    setSizeAndPositionToContent()
    drawToggleButton()
    drawAffectsWindows()
    drawAffectsText()

    WindowShow(WIN, true)
  end
end

clear = function() 
  TEXT_BUFFER = {}
  BAD_STUFF = {}
  EXPANDED = false
  draw()
end

close = function()
  save()
  CONFIG = nil
  WindowShow(WIN, false)  
end

save = function()
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG, CONFIG)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION, POSITION)
end

getConfiguration = function()
  local expand_direction = (CONFIG.EXPAND_DOWN and "Down" or "Up") .. "/" .. (CONFIG.EXPAND_RIGHT and "Right" or "Left")
  
  return {
    OPTIONS = {
      ENABLED = config_window.CreateBoolOption(1, "Enabled", CONFIG.ENABLED, "Whether or not you should ever even see this window."),
      LOCK_POSITION = config_window.CreateBoolOption(2, "Lock Position", CONFIG.LOCK_POSITION, "Disable dragging to move the panel."),
      EXPAND = config_window.CreateListOption(3, "Expand Direction", expand_direction, EXPAND_DIRECTION_LIST, "Set the direction the window will expand from the button."),
      EXTRA_AFFECTS = config_window.CreateTextOption(4, "Extra Affects", CONFIG.EXTRA_AFFECTS, "Other affects you want to see in this list.", true, 17)
    },
    BUTTON = {
      BUTTON_FONT = config_window.CreateFontOption(1, "Button Font", CONFIG.BUTTON_FONT, "The font used for the button."),
      AFFECTS_FONT = config_window.CreateFontOption(2, "Affects Font", CONFIG.AFFECTS_FONT, "The font used for the affects."),
      BUTTON_HEIGHT = config_window.CreateNumberOption(3, "Height", CONFIG.BUTTON_HEIGHT, 5, consts.GetClientHeight(), "The height of the button."),
      BUTTON_WIDTH = config_window.CreateNumberOption(4, "Width", CONFIG.BUTTON_WIDTH, 10, consts.GetClientWidth(), "The width of the button."),
      BUTTON_LABEL = config_window.CreateTextOption(5, "Label", CONFIG.BUTTON_LABEL, "Set the text of the button."),
    },
    COLORS = {
      BACKGROUND_COLOR = config_window.CreateColorOption(1, "Background", CONFIG.BACKGROUND_COLOR, "The background color of the affects panel."),
      BORDER_COLOR = config_window.CreateColorOption(2, "Border", CONFIG.BORDER_COLOR, "The border color of the affects panel."),
      ACTIVE_BUTTON_COLOR = config_window.CreateColorOption(2, "Active Button", CONFIG.ACTIVE_BUTTON_COLOR, "The color of the button when you have affects."),
      ACTIVE_LABEL_COLOR = config_window.CreateColorOption(2, "Active Label", CONFIG.ACTIVE_LABEL_COLOR, "The color of the label when you have affects."),
      DISABLED_BUTTON_COLOR = config_window.CreateColorOption(2, "Inactive Button", CONFIG.DISABLED_BUTTON_COLOR, "The color of the button when you do not have affects."),
      DISABLED_LABEL_COLOR = config_window.CreateColorOption(2, "Inactive Label", CONFIG.DISABLED_LABEL_COLOR, "The color of the label when you do not have affects."),
    },
    POSITION = {
      WINDOW_LEFT = config_window.CreateNumberOption(1, "Left", POSITION.WINDOW_LEFT, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH, "The left most position of the entire panel."),
      WINDOW_TOP = config_window.CreateNumberOption(2, "Top", POSITION.WINDOW_TOP, 0, consts.GetClientHeight() - POSITION.WINDOW_HEIGHT, "The top most position of the entire panel."),
      ANCHOR = config_window.CreateListOption(5, "Preset", "Select...", ANCHOR_LIST, "Set the window position based on a set of preset rules."),
      Z_POSITION = config_window.CreateNumberOption(6, "Z Position", POSITION.Z_POSITION, -9999, 9999, "Increase this if your window is below another one and you need to see it.")
    }
  }
end

onConfigureDone = function(group_id, option_id, config)
  if group_id == "POSITION" then
    if option_id == "ANCHOR" then
      adjustAnchor(config.raw_value)
    else
      POSITION[option_id] = config.raw_value
    end

    if option_id == "Z_POSITION" then
      WindowSetZOrder(WIN, config.raw_value)
    end
  else
    if option_id == "EXPAND" then
      local expand = utils.split(EXPAND_DIRECTION_LIST[config.raw_value], '/')
      if expand[1] == "Up" then CONFIG.EXPAND_DOWN = false
      else CONFIG.EXPAND_DOWN = true end
      if expand[2] == "Left" then CONFIG.EXPAND_RIGHT = false
      else CONFIG.EXPAND_RIGHT = true end
    elseif option_id == "EXTRA_AFFECTS" then
      CONFIG.EXTRA_AFFECTS = {}
      for _, aff in ipairs(utils.split(Trim(config.raw_value):lower(), ",")) do
        CONFIG.EXTRA_AFFECTS[Trim(aff:lower())] = true
      end
    else
      CONFIG[option_id] = config.raw_value
    end
  end
  
  save()
  create()
  draw()
end

adjustAnchor = function(anchor_idx)
  local anchor = ANCHOR_LIST[anchor_idx]:sub(4)
  if anchor == nil or anchor == "" or anchor == "None" then
    return
  elseif anchor == "Top Left (Window)" then 
    POSITION.WINDOW_LEFT = 10
    POSITION.WINDOW_TOP = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Window)" then 
    POSITION.WINDOW_LEFT = 10
    POSITION.WINDOW_TOP = consts.GetClientHeight() - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Top Right (Window)" then
    POSITION.WINDOW_LEFT = consts.GetClientWidth() - CONFIG.BUTTON_WIDTH - 10
    POSITION.WINDOW_TOP = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Bottom Right (Window)" then
    POSITION.WINDOW_LEFT = consts.GetClientWidth() - CONFIG.BUTTON_WIDTH - 10
    POSITION.WINDOW_TOP = consts.GetClientHeight() - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Top Left (Output)" then
    POSITION.WINDOW_LEFT = consts.GetOutputLeft() + 10
    POSITION.WINDOW_TOP = consts.GetOutputTop() + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Output)" then
    POSITION.WINDOW_LEFT = consts.GetOutputLeft() + 10
    POSITION.WINDOW_TOP = consts.GetOutputBottom() - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor ==  "Top Right (Output)" then
    POSITION.WINDOW_LEFT = consts.GetOutputRight() - 10
    POSITION.WINDOW_TOP = consts.GetOutputTop() + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor ==  "Bottom Right (Output)" then
    POSITION.WINDOW_LEFT = consts.GetOutputRight() - 10
    POSITION.WINDOW_TOP = consts.GetOutputBottom() - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = false
  end

  --Note("Set anchor points: " .. anchor .. " (" .. POSITION.WINDOW_LEFT .. ", " .. POSITION.WINDOW_TOP .. ")")

  setSizeAndPositionToContent()
end

setSizeAndPositionToContent = function()
  local left = math.max(WindowInfo(WIN, 1), 0)
  local top = math.max(WindowInfo(WIN, 2), 0)
  local right = left + WindowInfo(WIN, 3)
  local bottom = top + WindowInfo(WIN, 4)

  local final_width = CONFIG.BUTTON_WIDTH or 100
  local column1Final, column2Final = 0, 0
  local final_height = CONFIG.BUTTON_HEIGHT or 25

  TEXT_BUFFER = {}
  for aff, time in pairs(BAD_STUFF) do
    if time > os.time() then
      table.insert(TEXT_BUFFER, { affect = aff, expire = time })
    end
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

    for _, details in ipairs(TEXT_BUFFER) do
      if details ~= nil and details.affect ~= nil and details.expire ~= nil then
        local col1Width = WindowTextWidth(WIN, AFFECTSFONT, details.affect)
        local col2Width = WindowTextWidth(WIN, AFFECTSFONT, getFriendlyExpire(details.expire))

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

  POSITION.WINDOW_WIDTH = math.max(final_width, CONFIG.BUTTON_WIDTH)
  POSITION.WINDOW_HEIGHT = math.max(final_height, CONFIG.BUTTON_HEIGHT)

  local new_left = 0
  local new_top = 0

  POSITION.WINDOW_LEFT = POSITION.WINDOW_LEFT or left
  POSITION.WINDOW_TOP = POSITION.WINDOW_TOP or top

  if CONFIG.EXPAND_RIGHT then
    new_left = POSITION.WINDOW_LEFT
  else
    new_left = POSITION.WINDOW_LEFT - POSITION.WINDOW_WIDTH
  end

  if CONFIG.EXPAND_DOWN then
    new_top = POSITION.WINDOW_TOP
  else
    new_top = POSITION.WINDOW_TOP - POSITION.WINDOW_HEIGHT
  end

  WindowPosition(WIN, new_left, new_top, 4, 2)
  WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, 0)
  WindowSetZOrder(WIN, POSITION.Z_POSITION)
end

drawToggleButton = function()
  local text_width = WindowTextWidth(WIN, BUTTONFONT, CONFIG.BUTTON_LABEL)
  local left = 0
  local top = 0
  local right = CONFIG.BUTTON_WIDTH  
  local bottom = CONFIG.BUTTON_HEIGHT

  if not CONFIG.EXPAND_RIGHT then
    left = POSITION.WINDOW_WIDTH - CONFIG.BUTTON_WIDTH
    right = POSITION.WINDOW_WIDTH
  end

  if not CONFIG.EXPAND_DOWN then
    top = POSITION.WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT
    bottom = POSITION.WINDOW_HEIGHT
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

  WindowAddHotspot(WIN, "badaffects_button", left, top, button_right, bottom, "", "", "", "", "badaffects_buttonClick", "", cursor, 0)

  if not CONFIG.LOCK_POSITION then
    WindowRectOp(WIN, miniwin.rect_fill, button_right, top, right, bottom, CURRENT_BUTTON_COLOR)
    WindowLine(WIN, button_right + 3, top + 8, right - 3, top + 8, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 12, right - 3, top + 12, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 16, right - 3, top + 16, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)

    WindowAddHotspot(WIN, "drag_" .. WIN, button_right, top, right, bottom, "", "", "badaffects_dragMouseDown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "badaffects_dragMouseMove", "badaffects_dragMouseRelease", 0)
  end
end

function badaffects_dragMouseDown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)
end

function badaffects_dragMouseMove(flags, hotspot_id)
  local pos_x = consts.clamp(WindowInfo(WIN, 17) - DRAG_X, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH)
  local pos_y = consts.clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, consts.GetClientHeight() - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function badaffects_dragMouseRelease(flags, hotspot_id)
  Repaint()
  save()
end

drawAffectsWindows = function()
  if EXPANDED then
    local top = 0
    local bottom = POSITION.WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT

    local left_clear = 0
    local top_clear = POSITION.WINDOW_HEIGHT - CONFIG.BUTTON_HEIGHT
    local right_clear = POSITION.WINDOW_WIDTH - CONFIG.BUTTON_WIDTH
    local bottom_clear = POSITION.WINDOW_HEIGHT

    if CONFIG.EXPAND_DOWN then
      top = CONFIG.BUTTON_HEIGHT
      bottom = POSITION.WINDOW_HEIGHT

      top_clear = 0
      bottom_clear = CONFIG.BUTTON_HEIGHT
    end

    if CONFIG.EXPAND_RIGHT then
      left_clear = CONFIG.BUTTON_WIDTH
      right_clear = POSITION.WINDOW_WIDTH
    end

    WindowRectOp(WIN, miniwin.rect_fill, 0, top, POSITION.WINDOW_WIDTH, bottom, CONFIG.BACKGROUND_COLOR)
    WindowRectOp(WIN, miniwin.rect_frame, 0, top, POSITION.WINDOW_WIDTH, bottom, CONFIG.BORDER_COLOR)
    WindowRectOp(WIN, miniwin.rect_fill, left_clear, top_clear, right_clear, bottom_clear, ColourNameToRGB("black"))
  end
end

drawAffectsText = function()
  if EXPANDED then
    local y = 4
    if CONFIG.EXPAND_DOWN then
      y = y + CONFIG.BUTTON_HEIGHT
    end
    
    for i = 1, #TEXT_BUFFER do
      local x = 4
      if y + LINE_HEIGHT > POSITION.WINDOW_HEIGHT then
        break
      end

      local details = TEXT_BUFFER[i]
      
      if details ~= nil and details.affect ~= nil and details.expire ~= nil then
        local expires_in = details.expire - os.time()
        if expires_in > 0 then
          WindowText(WIN, BUTTONFONT, details.affect, x + 2, y, 0, 0, CONFIG.AFFECTS_FONT.colour)
          WindowText(WIN, BUTTONFONT, "-", COL_1_WIDTH + 10, y, 0, 0, CONFIG.BORDER_COLOR)
          WindowText(WIN, BUTTONFONT, getFriendlyExpire(expires_in), COL_1_WIDTH + 22, y, 0, 0, CONFIG.AFFECTS_FONT.colour)
          y = y + LINE_HEIGHT
        end
      end
    end
  end
end

setAffect = function(aff, time, redraw)
  if CONFIG ~= nil and CONFIG.ENABLED and (CONFIG.EXTRA_AFFECTS[aff] or NEGATIVE_AFFECTS[aff]) then
    EXPANDED = true

    if BAD_STUFF == nil then 
      BAD_STUFF = {}
    end

    if (time == 0) then
      removeAffect(aff)
    else
      BAD_STUFF[aff] = os.time() + (time / 4 * 60)
    end

    if redraw then
      draw()
    end
  end
end

removeAffect = function(affect, redraw)
  if CONFIG.ENABLED then
    if BAD_STUFF == nil then 
      BAD_STUFF = {}
    end

    BAD_STUFF[affect] = nil

    if redraw then
      draw()
    end
  end
end

getFriendlyExpire = function(expires_in)
  if (expires_in > 0) then
    local minutes = expires_in / 60
    local mins = math.floor(minutes)
    local secs = math.floor((minutes - mins) * 60) 
    
    return mins .. " minutes and " .. secs .. " seconds.";
  end

  return nil
end

function badaffects_buttonClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if #TEXT_BUFFER > 0 then
      EXPANDED = not EXPANDED
      draw()
    end
  end
  if flags == miniwin.hotspot_got_rh_mouse then
    local menu_items = ""
    if CONFIG.LOCK_POSITION then menu_items = menu_items .. "+" end
    menu_items = menu_items .. "Lock Position | >Anchor | "
    for _, a in ipairs(ANCHOR_LIST) do
      menu_items = menu_items .. a .. " | "
    end
    menu_items = menu_items .. " < | - | Disable | - | Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Lock Position" then
      CONFIG.LOCK_POSITION = not CONFIG.LOCK_POSITION
    elseif result == "Disable" then
      CONFIG.ENABLED = false
      WindowShow(WIN, false)
    elseif result == "Configure" then
      config_window.Show(getConfiguration(), onConfigureDone)
    else
      for i, a in ipairs(ANCHOR_LIST) do
        if result == a then
          adjustAnchor(i)
        end
      end
    end
    save()
    draw()
  end
end

return {
  Initialize = initialize, 
  Draw = draw,
  Clear = clear,
  Close = close, 
  Save = save, 
  GetConfiguration = getConfiguration, 
  OnConfigureDone = onConfigureDone, 
  SetAffect = setAffect, 
  RemoveAffect = removeAffect
}