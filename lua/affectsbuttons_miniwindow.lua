local serializer_installed, serialization_helper = pcall(require, "serializationhelper")
local config_installed, config_window = pcall(require, "configuration_miniwindow")
local const_installed, consts = pcall(require, "consthelper")

local prepare, initialize, load, create, draw, drawWindow, isEmptyButton, dragMouseDown, dragMouseMove,
  dragMouseRelease, clear, close, save, setAffect, removeAffect, checkDuration, checkForNotifyAdd, checkForNotifyRemove,
  getConfiguration, onConfigureDone, adjustAnchor, drawHeader, drawAffect, createFavoriteStar, getExpiration, isAutoUpdateEnabled,
  getButtonColor, getTimeFromMinutes, castFavorites, getDuration,
  addButton, editButton, renameButton, deleteButton, moveButtonUp, moveButtonDown, toggleFavorite, toggleBroadcast, getTooltip

local WIN = "affectsbuttons_" .. GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local HEADERFONT = WIN .. "_header_font"

local CONFIG = nil
local BUTTONS = nil
local BROADCAST = nil
local POSITION = nil
local DURATIONS = nil

local CHARACTER_NAME = ""
local HAS_ACTIVE_AFFECTS = true
local CURRENT_AFFECTS = {}
local PERM_AFFECTS = {}
local LONGEST_TITLE = 0
local CURRENT_COMMAND = nil
local LINE_HEIGHT = nil
local DRAG_X = nil
local DRAG_Y = nil

local ANCHOR_LIST = { 
  "0: None", "1: Left (Window)", "2: Right (Window)", "3. Left (Output)", "4. Right (Output)"
}

local SERIALIZE_TAGS = { 
  LAST_CONFIG = "last_affectsbuttons_config", CONFIG = "_affectsbuttons_config", BUTTONS = "_affectsbuttons_buttons",
  BROADCAST = "_affectsbuttons_broadcast", POSITION = "_affectsbuttons_position", DURATIONS = "affects_durations"
}

prepare = function()
  local last_config = serialization_helper.GetSerializedVariable(SERIALIZE_TAGS.LAST_CONFIG)
  if last_config.left ~= nil then    
    WindowCreate(WIN, last_config.left, last_config.top, last_config.width, last_config.height, 12, 2, last_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, last_config.width, last_config.height, last_config.bgcolor)
    WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, last_config.border)
    WindowShow(WIN, true)
  end
end

initialize = function(character_name)
  CHARACTER_NAME = character_name

  load()
  create()
  draw()
end

load = function()
  CONFIG = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG)
  BUTTONS = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.BUTTONS)
  BROADCAST = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.BROADCAST)
  POSITION = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION)
  DURATIONS = serialization_helper.GetSerializedVariable(SERIALIZE_TAGS.DURATIONS)
  
  CONFIG.BUTTON_FONT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_FONT, { name = "Trebuchet MS", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.HEADER_FONT = serialization_helper.GetValueOrDefault(CONFIG.HEADER_FONT, { name = "Trebuchet MS", size = 9, colour = 12632256, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BUTTON_HEIGHT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_HEIGHT, 25)
  CONFIG.BUTTON_WIDTH = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_WIDTH, 140)
  CONFIG.HORIZONTAL_PADDING = serialization_helper.GetValueOrDefault(CONFIG.HORIZONTAL_PADDING, 5)
  CONFIG.VERTICAL_PADDING = serialization_helper.GetValueOrDefault(CONFIG.VERTICAL_PADDING, 5)
  CONFIG.AUTO_HEIGHT  = serialization_helper.GetValueOrDefault(CONFIG.AUTO_HEIGHT, true)
  CONFIG.AUTO_WIDTH  = serialization_helper.GetValueOrDefault(CONFIG.AUTO_WIDTH, false)
  CONFIG.LOCK_POSITION = serialization_helper.GetValueOrDefault(CONFIG.LOCK_POSITION, false)

  CONFIG.SHOW_HEADER = serialization_helper.GetValueOrDefault(CONFIG.SHOW_HEADER, true)  
  CONFIG.HEADER_TEXT = serialization_helper.GetValueOrDefault(CONFIG.HEADER_TEXT, "~ Affects ~")
  CONFIG.SHOW_EMPTY_AS_HEADER = serialization_helper.GetValueOrDefault(CONFIG.SHOW_EMPTY_AS_HEADER, true)

  CONFIG.SHOW_CAST_FAVORITES = serialization_helper.GetValueOrDefault(CONFIG.SHOW_CAST_FAVORITES, true)
  CONFIG.CAST_FAVORITES_LABEL = serialization_helper.GetValueOrDefault(CONFIG.CAST_FAVORITES_LABEL, "All Favorites")
  CONFIG.FAVORITE_BORDER = serialization_helper.GetValueOrDefault(CONFIG.FAVORITE_BORDER, consts.black)
  CONFIG.FAVORITE_COLOR = serialization_helper.GetValueOrDefault(CONFIG.FAVORITE_COLOR, ColourNameToRGB("gold"))
  CONFIG.FAVORITE_ICON_SIZE = serialization_helper.GetValueOrDefault(CONFIG.FAVORITE_ICON_SIZE, 5)

  CONFIG.BACKGROUND_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BACKGROUND_COLOR, 0)
  CONFIG.BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BORDER_COLOR, consts.border_color)
  CONFIG.BUTTON_BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_BORDER_COLOR, 8421504)
  CONFIG.NEUTRAL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.NEUTRAL_COLOR, 8421504)
  CONFIG.EXPIRED_COLOR = serialization_helper.GetValueOrDefault(CONFIG.EXPIRED_COLOR, 255)
  CONFIG.CASTED_COLOR = serialization_helper.GetValueOrDefault(CONFIG.CASTED_COLOR, 32768)
  CONFIG.EXPIRING_COLOR = serialization_helper.GetValueOrDefault(CONFIG.EXPIRING_COLOR, 65535)
    
  CONFIG.REFRESH_TIME = serialization_helper.GetValueOrDefault(CONFIG.REFRESH_TIME, 10)  
  CONFIG.AUTOUPDATE = serialization_helper.GetValueOrDefault(CONFIG.AUTOUPDATE, true)
  CONFIG.Z_POSITION = serialization_helper.GetValueOrDefault(CONFIG.Z_POSITION, 500)

  POSITION.WINDOW_LEFT = serialization_helper.GetValueOrDefault(POSITION.WINDOW_LEFT, consts.GetOutputRightOutside())
  POSITION.WINDOW_TOP = serialization_helper.GetValueOrDefault(POSITION.WINDOW_TOP, consts.GetOutputTopOutside() + 1)
  POSITION.WINDOW_WIDTH = serialization_helper.GetValueOrDefault(POSITION.WINDOW_WIDTH, CONFIG.BUTTON_WIDTH + CONFIG.HORIZONTAL_PADDING * 2)
  POSITION.WINDOW_HEIGHT = serialization_helper.GetValueOrDefault(POSITION.WINDOW_HEIGHT,  (#BUTTONS * 30) + 60)

  -- POSITION.WINDOW_HEIGHT = consts.clamp(POSITION.WINDOW_HEIGHT, 10, consts.GetClientHeight())
  -- POSITION.WINDOW_WIDTH = consts.clamp(POSITION.WINDOW_WIDTH, 10, consts.GetClientWidth())
  -- POSITION.WINDOW_TOP = consts.clamp(POSITION.WINDOW_TOP, 0, consts.GetClientHeight() - POSITION.WINDOW_HEIGHT)
  -- POSITION.WINDOW_LEFT = consts.clamp(POSITION.WINDOW_LEFT, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH)

  if CONFIG.REFRESH_TIME > 0 then
    SetTimerOption ("affects_timer", "second", CONFIG.REFRESH_TIME)
    EnableTimer("affects_timer", true)
  else
    Note("The affects_button plugin 'refresh time' option is not set, the panel will only update when it receives events.")
    EnableTimer("affects_timer", false)
  end

  LONGEST_TITLE = 0
  if (#BUTTONS == 0) then
    Note("Looks like you don't have any buttons set up yet.")
    Note("Type 'affects add' to add your first one.")
  else
    for _, button in ipairs(BUTTONS) do
      LONGEST_TITLE = math.max(LONGEST_TITLE, " " .. WindowTextWidth(WIN, BUTTONFONT, button.title) .. " ")
    end
  end
end

create = function()
  local btnfont = CONFIG["BUTTON_FONT"]
  local hdrfont = CONFIG["HEADER_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)

  WindowFont(WIN, BUTTONFONT, btnfont.name, btnfont.size, 
    serialization_helper.ConvertToBool(btnfont.bold), 
    serialization_helper.ConvertToBool(btnfont.italic), 
    serialization_helper.ConvertToBool(btnfont.italic), 
    serialization_helper.ConvertToBool(btnfont.strikeout))

  WindowFont(WIN, HEADERFONT, hdrfont.name, hdrfont.size, 
    serialization_helper.ConvertToBool(hdrfont.bold), 
    serialization_helper.ConvertToBool(hdrfont.italic), 
    serialization_helper.ConvertToBool(hdrfont.italic), 
    serialization_helper.ConvertToBool(hdrfont.strikeout))

  WindowSetZOrder(WIN, CONFIG.Z_POSITION)

  LINE_HEIGHT = WindowFontInfo(WIN, BUTTONFONT, 1)
  CONFIG.BUTTON_HEIGHT = math.max(CONFIG.BUTTON_HEIGHT, LINE_HEIGHT + 2)
end

draw = function()
  if CONFIG == nil then return end
  HAS_ACTIVE_AFFECTS = false  
  WindowShow(WIN, false)
  drawWindow()

  local y = drawHeader(CONFIG.HEADER_TEXT, consts.GetBorderWidth(), true)

  if CONFIG.SHOW_CAST_FAVORITES then
    y = drawAffect(nil, CONFIG.CAST_FAVORITES_LABEL, "affects cast favorites", y, false)
  end
  
  for _, v in ipairs(BUTTONS) do
    if isEmptyButton(v) and CONFIG.SHOW_EMPTY_AS_HEADER then
      y = drawHeader(v["title"], y, false)
    else
      y = drawAffect(v["affect"], v["title"], v["action"], y, v["favorite"] or false)
    end
  end

  if not HAS_ACTIVE_AFFECTS then
    EnableTimer("affects_timer", false)
  elseif CONFIG.REFRESH_TIME > 0 then
    EnableTimer("affects_timer", true)
  end

  WindowShow(WIN, true)
end

drawWindow = function()
  if CONFIG == nil then return end
  if CONFIG.AUTO_HEIGHT then
    local button_height = CONFIG.VERTICAL_PADDING * 2 + CONFIG.BUTTON_HEIGHT
    local height = #BUTTONS * button_height + consts.GetBorderWidth() * 2
    if CONFIG.SHOW_HEADER then height = height + button_height end
    if CONFIG.SHOW_CAST_FAVORITES then height = height + button_height end
    POSITION.WINDOW_HEIGHT = consts.clamp(height, 10, consts.GetClientHeight())
  end

  if CONFIG.AUTO_WIDTH then
    CONFIG.BUTTON_WIDTH = math.max(CONFIG.BUTTON_WIDTH, LONGEST_TITLE + 2)
    local width = CONFIG.HORIZONTAL_PADDING * 2 + CONFIG.BUTTON_WIDTH + consts.GetBorderWidth() * 2    
    POSITION.WINDOW_WIDTH = consts.clamp(width, 10 + (CONFIG.HORIZONTAL_PADDING * 2), consts.GetClientWidth())
  end

  WindowPosition(WIN, POSITION.WINDOW_LEFT, POSITION.WINDOW_TOP, 4, 2)
  WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, consts.black)
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, CONFIG.BACKGROUND_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, CONFIG.BORDER_COLOR)

  for i = 0, consts.GetBorderWidth() - 1 do
    WindowRectOp(WIN, miniwin.rect_frame, 0 + i, 0 + i, POSITION.WINDOW_WIDTH - i, POSITION.WINDOW_HEIGHT - i, CONFIG.BORDER_COLOR)
  end
end

drawHeader = function(header_text, y_pos, is_main_header)
  if not is_main_header or CONFIG.SHOW_HEADER then
    local bottom = y_pos + CONFIG.BUTTON_HEIGHT + CONFIG.VERTICAL_PADDING * 2
    local text_width = math.min(POSITION.WINDOW_WIDTH, WindowTextWidth(WIN, HEADERFONT, header_text, true))
    local center_pos_x = (POSITION.WINDOW_WIDTH - text_width) / 2
    WindowText(WIN, HEADERFONT, header_text, center_pos_x, y_pos + CONFIG.VERTICAL_PADDING, 0, 0, CONFIG.HEADER_FONT.colour, false)

    if is_main_header then
      if not CONFIG.LOCK_POSITION then
        WindowAddHotspot(WIN, "drag_" .. WIN, 0, 0, POSITION.WINDOW_WIDTH, bottom, "", "", "affectsbuttons_dragMouseDown", "", "", "", 10, 0)
        WindowDragHandler (WIN, "drag_" .. WIN, "affectsbuttons_dragMouseMove", "affectsbuttons_dragMouseRelease", 0)
      else
        WindowAddHotspot(WIN, "drag_" .. WIN, 0, 0, POSITION.WINDOW_WIDTH, bottom, "", "", "affectsbuttons_dragMouseDown", "", "", "", 0, 0)
      end
    else
      WindowAddHotspot(WIN, header_text .. "~~", consts.GetBorderWidth(), y_pos, POSITION.WINDOW_WIDTH - consts.GetBorderWidth(), bottom, "", "", 
        "affectsbuttons_buttonMouseDown", "affectsbuttons_buttonMouseCancel", "affectsbuttons_buttonMouseUp", "", 0, 0)
    end
    
    return bottom
  end

  return y_pos
end

drawAffect = function(affect, title, command, top_pos, favorite)
  if not title then return top_pos end

  local expires_in = getExpiration(affect)
  local button_color = getButtonColor(expires_in)
  local top = top_pos + CONFIG.VERTICAL_PADDING
  local left = consts.GetBorderWidth() + CONFIG.HORIZONTAL_PADDING
  local right = POSITION.WINDOW_WIDTH - consts.GetBorderWidth() - CONFIG.HORIZONTAL_PADDING
  local bottom = top + CONFIG.BUTTON_HEIGHT
  local middle_y = top + CONFIG.BUTTON_HEIGHT / 2 - LINE_HEIGHT / 2

  WindowRectOp(WIN, miniwin.rect_fill, left, top, right, bottom, button_color)

  if favorite then 
    -- todo: different ways to rep, star, border color
    local star_points = createFavoriteStar(CONFIG.FAVORITE_ICON_SIZE, right - CONFIG.FAVORITE_ICON_SIZE * 2, top + CONFIG.BUTTON_HEIGHT / 2)
    WindowPolygon(WIN, star_points, CONFIG.FAVORITE_BORDER, miniwin.pen_solid, 1, CONFIG.FAVORITE_COLOR, miniwin.brush_solid, true)
  end

  local text_width = WindowTextWidth(WIN, BUTTONFONT, title, true)
  local middle_pos = (POSITION.WINDOW_WIDTH - text_width) / 2
  local tooltip = getTooltip(expires_in) or title
  WindowText(WIN, BUTTONFONT, title, middle_pos, middle_y, 0, 0, CONFIG.BUTTON_FONT.colour, true)
  WindowRectOp(WIN, miniwin.rect_frame, left, top, right, bottom, CONFIG.BUTTON_BORDER_COLOR)
  WindowAddHotspot(WIN, title .. "~" .. command .. "~" .. (affect or ""), left, top, right, bottom, "", "", "affectsbuttons_buttonMouseDown", "affectsbuttons_buttonMouseCancel", "affectsbuttons_buttonMouseUp", tooltip, 1, 0)

  if expires_in ~= nil and expires_in > 0 and expires_in ~= 666666666 then
    HAS_ACTIVE_AFFECTS = true
  end

  local max_duration = DURATIONS[affect] or 300
  local current = consts.clamp(expires_in, 0, max_duration)
  local meter_right = consts.clamp((right - left) * (current / max_duration), 0, right)
  
  WindowRectOp(WIN, miniwin.rect_fill, left, bottom, right, bottom + CONFIG.VERTICAL_PADDING, CONFIG.BACKGROUND_COLOR)
  WindowRectOp(WIN, miniwin.rect_fill, left, bottom, left + meter_right, bottom + CONFIG.VERTICAL_PADDING, button_color)
  WindowRectOp(WIN, miniwin.rect_frame, left, bottom, right, bottom + CONFIG.VERTICAL_PADDING, CONFIG.BUTTON_BORDER_COLOR)

  return bottom + CONFIG.VERTICAL_PADDING
end

createFavoriteStar = function(size, offsetX, offsetY)
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

isEmptyButton = function(btn)
  local aff = btn["affect"] or ""
  local act = btn["action"] or ""
  return aff == "" and act == ""
end

function affectsbuttons_dragMouseDown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)

  if (flags == miniwin.hotspot_got_rh_mouse) then
    local menu_items = "Add Button | Hide Header | "
    if CONFIG.LOCK_POSITION then menu_items = menu_items .. "+" end
    menu_items = menu_items .. "Lock Position | >Anchor | "
    for _, a in ipairs(ANCHOR_LIST) do
      menu_items = menu_items .. a .. " | "
    end
    menu_items = menu_items .. " < | - | Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Add Button" then
      addButton(nil, nil, nil)
    elseif result == "Hide Header" then
      CONFIG.SHOW_HEADER = false
    elseif result == "Lock Position" then
      CONFIG.LOCK_POSITION = not CONFIG.LOCK_POSITION    
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

function affectsbuttons_dragMouseMove(flags, hotspot_id)
  local pos_x = consts.clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - POSITION.WINDOW_WIDTH)
  local pos_y = consts.clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function affectsbuttons_dragMouseRelease(flags, hotspot_id)
  POSITION.WINDOW_LEFT = WindowInfo(WIN, 10)
  POSITION.WINDOW_TOP = WindowInfo(WIN, 11)
  Repaint()
  save()
end

clear = function()
  local possible_wolf = CURRENT_AFFECTS["wolf_familiar"]
  CURRENT_AFFECTS = {}
  PERM_AFFECTS = {}
  if possible_wolf ~= nil then
    CURRENT_AFFECTS["wolf_familiar"] = possible_wolf
  end
end

close = function()
  save()
  CONFIG = nil
  WindowShow(WIN, false)
end

save = function()
  local sticky_options = { 
    left = WindowInfo(WIN, 10), top = WindowInfo(WIN, 11), 
    width = WindowInfo(WIN, 3), height = WindowInfo(WIN, 4), 
    bgcolor = CONFIG.BACKGROUND_COLOR, 
    border = CONFIG.BORDER_COLOR, 
  }

  serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.LAST_CONFIG, sticky_options)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG, CONFIG)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.BUTTONS, BUTTONS)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.BROADCAST, BROADCAST)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION, POSITION)
  serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.DURATIONS, DURATIONS)
end

setAffect = function(affect, time, notify, refresh)
  if (time == 0) then
    removeAffect(affect, notify)
  else
    if time == -1 then
      PERM_AFFECTS[affect] = 1
    else
      if CONFIG.REFRESH_TIME > 0 then
        EnableTimer("affects_timer", true)
      end
      local previous_temp = CURRENT_AFFECTS[affect] or 0
      CURRENT_AFFECTS[affect] = os.time() + (time / 4 * 60)

      checkDuration(affect)
      checkForNotifyAdd(notify, affect, previous_temp)
    end

    if refresh == nil or refresh == true then
      draw()
    end
  end
end

removeAffect = function(affect, notify, refresh)
  local previous_temp = CURRENT_AFFECTS[affect] or 0

  CURRENT_AFFECTS[affect] = 0
  PERM_AFFECTS[affect] = 0

  checkForNotifyRemove(notify, affect, previous_temp)

  if refresh == nil or refresh == true then
    draw()
  end
end

checkDuration = function(affect)
  local expires_in = CURRENT_AFFECTS[affect] - os.time()
  if DURATIONS[affect] == nil or DURATIONS[affect] < expires_in then
    DURATIONS[affect] = expires_in
    serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.DURATIONS, DURATIONS)
  end
end

checkForNotifyAdd = function(notify, affect, highest_prev)
  if notify and highest_prev == 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU GAINED " .. affect:upper() .. " !!!")
  end
end

checkForNotifyRemove = function(notify, affect, highest_prev)
  if notify and highest_prev > 0 and BROADCAST[affect] then
    BroadcastPlugin(1, "!!! YOU LOST " .. affect:upper() .. " !!!")
  end
end

getConfiguration = function()
  return {
    OPTIONS = {
      REFRESH_TIME = config_window.CreateNumberOption(1, "Refresh Time", CONFIG.REFRESH_TIME, 0, 1000, "The amount of time before updating the UI."),
      AUTOUPDATE = config_window.CreateBoolOption(2, "Auto-Update", CONFIG.AUTOUPDATE, "Whether or not this plugins will try to update on close.")
    },
    PANEL = {
      AUTO_HEIGHT = config_window.CreateBoolOption(1, "Auto Height", CONFIG.AUTO_HEIGHT, "Automatically size the panel height based on the contents."),
      AUTO_WIDTH = config_window.CreateBoolOption(2, "Auto Width", CONFIG.AUTO_WIDTH, "Automatically size the panel width based on the contents."),
      LOCK_POSITION = config_window.CreateBoolOption(3, "Lock Position", CONFIG.LOCK_POSITION, "Disable dragging to move the panel."),
      BACKGROUND_COLOR = config_window.CreateColorOption(4, "Background", CONFIG.BACKGROUND_COLOR, "The background color of the entire panel."),
      BORDER_COLOR = config_window.CreateColorOption(5, "Border", CONFIG.BORDER_COLOR, "The border color of the entire panel."),
    },
    BUTTONS = {    
      BUTTON_FONT = config_window.CreateFontOption(1, "Font", CONFIG.BUTTON_FONT, "The font used for buttons."),
      BUTTON_HEIGHT = config_window.CreateNumberOption(2, "Height", CONFIG.BUTTON_HEIGHT, 5, 200, "The height of each button."),
      BUTTON_WIDTH = config_window.CreateNumberOption(3, "Width", CONFIG.BUTTON_WIDTH, 10, 600, "The width of each button. Ignored if auto width is enabled.", not CONFIG.AUTO_WIDTH),
      PADDING = {
        HORIZONTAL_PADDING = config_window.CreateNumberOption(1, "Horizontal", CONFIG.HORIZONTAL_PADDING, 0, 100, "The empty space between the window edge and the button."),
        VERTICAL_PADDING = config_window.CreateNumberOption(2, "Vertical", CONFIG.VERTICAL_PADDING, 10, 50, "The empty space before and after each button."),
      },
      COLORS = {
        BUTTON_BORDER_COLOR = config_window.CreateColorOption(1, "Border", CONFIG.BUTTON_BORDER_COLOR, "The border color of each button."),
        NEUTRAL_COLOR = config_window.CreateColorOption(2, "Neutral", CONFIG.NEUTRAL_COLOR, "The color of buttons not tied to an affect."),
        CASTED_COLOR = config_window.CreateColorOption(3, "Casted", CONFIG.CASTED_COLOR, "The color of buttons with an affect lasting over 5 minutes."),
        EXPIRING_COLOR = config_window.CreateColorOption(4, "Expiring", CONFIG.EXPIRING_COLOR, "The color of buttons with an affect lasting under 5 minutes."),
        EXPIRED_COLOR = config_window.CreateColorOption(5, "Expired", CONFIG.EXPIRED_COLOR, "The color of buttons with an affect that is not active."),
      }
    },
    HEADERS = {
      SHOW_HEADER = config_window.CreateBoolOption(1, "Show Main", CONFIG.SHOW_HEADER, "Show the main header above all buttons."),
      HEADER_TEXT = config_window.CreateTextOption(2, "Text", CONFIG.HEADER_TEXT, "Set what you want the main header to display."),
      HEADER_FONT = config_window.CreateFontOption(3, "Font", CONFIG.HEADER_FONT, "The font used for headers."),
      SHOW_EMPTY_AS_HEADER = config_window.CreateBoolOption(4, "Empty as Headers", CONFIG.SHOW_EMPTY_AS_HEADER, "Buttons that do not have an affect or command can be styled as a header."),
    },
    FAVORITES = {
      SHOW_CAST_FAVORITES = config_window.CreateBoolOption(1, "Show Button", CONFIG.SHOW_CAST_FAVORITES, "Show the button to cast all buttons marked as a favorite at once."),
      CAST_FAVORITES_LABEL = config_window.CreateTextOption(2, "Text", CONFIG.CAST_FAVORITES_LABEL, "Set what you want the favorites button to display."),
      ICON = {
        FAVORITE_ICON_SIZE = config_window.CreateNumberOption(1, "Size", CONFIG.FAVORITE_ICON_SIZE, 0, 20, "Size of the star marking a button as a favorite."),
        FAVORITE_COLOR = config_window.CreateColorOption(2, "Color", CONFIG.FAVORITE_COLOR, "The inner color of the favorites star icon."),
        FAVORITE_BORDER = config_window.CreateColorOption(3, "Border", CONFIG.FAVORITE_BORDER, "The border color of the favorites star icon."),
      }
    },
    POSITION = {
      WINDOW_LEFT = config_window.CreateNumberOption(1, "Left", POSITION.WINDOW_LEFT, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH, "The left most position of the entire panel."),
      WINDOW_TOP = config_window.CreateNumberOption(2, "Top", POSITION.WINDOW_TOP, 0, consts.GetClientHeight() - POSITION.WINDOW_HEIGHT, "The top most position of the entire panel."),
      WINDOW_WIDTH = config_window.CreateNumberOption(3, "Width", POSITION.WINDOW_WIDTH, 10, consts.GetClientWidth(), "The width of the entire panel. Ignored if auto width is enabled.", (not CONFIG.AUTO_WIDTH)),
      WINDOW_HEIGHT = config_window.CreateNumberOption(4, "Height", POSITION.WINDOW_HEIGHT, 10, consts.GetClientHeight(), "The height of the entire panel. Ignored if auto height is enabled.", (not CONFIG.AUTO_HEIGHT)),
      ANCHOR = config_window.CreateListOption(5, "Preset", "Select...", ANCHOR_LIST, "Anchor the window based on a set of preset rules. Can change all position values and auto width or auto height."),
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
    
    if not CONFIG.AUTO_HEIGHT then
      POSITION.WINDOW_HEIGHT = consts.clamp(POSITION.WINDOW_HEIGHT, 10, consts.GetClientHeight())
    end
    if not CONFIG.AUTO_WIDTH then
      POSITION.WINDOW_WIDTH = consts.clamp(POSITION.WINDOW_WIDTH, 10, consts.GetClientWidth())
    end

    POSITION.WINDOW_TOP = consts.clamp(POSITION.WINDOW_TOP, 0, consts.GetClientHeight() - POSITION.WINDOW_HEIGHT)
    POSITION.WINDOW_LEFT = consts.clamp(POSITION.WINDOW_LEFT, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH)  
  else
    CONFIG[option_id] = config.raw_value
    if option_id == "REFRESH_TIME" then
      if CONFIG.REFRESH_TIME > 0 then
        Note("Affect expirations will update automatically every " .. CONFIG.REFRESH_TIME .. " seconds.")
        SetTimerOption ("affects_timer", "second", CONFIG.REFRESH_TIME)
        EnableTimer("affects_timer", true)
      else
        Note("Refresh time has been set to zero, affect expirations will not update automatically.")
        EnableTimer("affects_timer", false)
      end
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
  elseif anchor == "Left (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_TOP = 0
    POSITION.WINDOW_HEIGHT = consts.GetClientHeight()
  elseif anchor == "Right (Window)" then
    POSITION.WINDOW_LEFT = consts.GetClientWidth() - POSITION.WINDOW_WIDTH
    POSITION.WINDOW_TOP = 0
    POSITION.WINDOW_HEIGHT = consts.GetClientHeight()
  elseif anchor == "Left (Output)" then
    POSITION.WINDOW_LEFT = math.max(0, consts.GetOutputLeftOutside() - POSITION.WINDOW_WIDTH)
    POSITION.WINDOW_TOP = consts.GetOutputTopOutside()
    POSITION.WINDOW_HEIGHT = consts.GetOutputHeight()
  elseif anchor ==  "Right (Output)" then
    POSITION.WINDOW_LEFT = math.min(consts.GetClientWidth() - POSITION.WINDOW_WIDTH, consts.GetOutputRightOutside())
    POSITION.WINDOW_TOP = consts.GetOutputTopOutside()
    POSITION.WINDOW_HEIGHT = consts.GetOutputHeight()
  end
end

getExpiration = function(affect)
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

getButtonColor = function(expires_in)
  if (expires_in == nil) then
    return CONFIG.NEUTRAL_COLOR
  elseif (expires_in <= 0) then
    return CONFIG.EXPIRED_COLOR
  elseif (expires_in > 300) then
    return CONFIG.CASTED_COLOR
  end

  return CONFIG.EXPIRING_COLOR
end

getTooltip = function(expires_in)
  if (expires_in ~= nil) then
    if (expires_in == 666666666) then
      return "permanent affect"
    elseif (expires_in > 0) then
      local m, s = getTimeFromMinutes(expires_in / 60)
      return m .. " minutes and " .. s .. " seconds.";
    end
  end

  return nil
end

getTimeFromMinutes = function(minutes)
  local mins = math.floor(minutes)
  local secs = math.floor((minutes - mins) * 60)
  return mins, secs
end

function affectsbuttons_buttonMouseDown(flags, hs_id)
  CURRENT_COMMAND = nil
  if (flags == miniwin.hotspot_got_lh_mouse) then
    local split = utils.split(hs_id, "~")
    CURRENT_COMMAND = split[2]
  end
end

function affectsbuttons_buttonMouseCancel(flags, hs_id)
  if CURRENT_COMMAND then CURRENT_COMMAND = nil end
end

function affectsbuttons_buttonMouseUp(flags, hs_id)
  if CURRENT_COMMAND then Execute(CURRENT_COMMAND) end
  if (flags == miniwin.hotspot_got_rh_mouse) then
    local split = utils.split(hs_id, "~")
    if split[1] == "All Favorites" then
      local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), "Configure")
      if result == "Configure" then
        config_window.Show(getConfiguration(), onConfigureDone)
      end
    else
      local menu_items = "Edit | Delete | Move Up | Move Down | - | Add Button | Configure"
      if PERM_AFFECTS[split[3]] ~= nil or (CURRENT_AFFECTS[split[3]] ~= nil and CURRENT_AFFECTS[split[3]] > os.time()) then
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
        editButton(split[1], nil, nil)
      elseif result == "Delete" then
        deleteButton(split[1])
      elseif result == "Move Up" then
        moveButtonUp(split[1])
      elseif result == "Move Down" then
        moveButtonDown(split[1])
      elseif result == "Add Button" then
        addButton(nil, nil, nil)
      elseif result == "Configure" then
        config_window.Show(getConfiguration(), onConfigureDone)
      elseif result == "Set Favorite" then
        setFavorite(split[1])
      end
    end
  end
end

castFavorites = function()
  local at_least_one = false
  local count = 0
  for _, button in ipairs(BUTTONS) do
    if button.favorite then
      at_least_one = true
      local expires_in = getExpiration(button.affect)
      
      local button_color = getButtonColor(expires_in)
      
      if button_color == CONFIG.EXPIRED_COLOR or 
         button_color == CONFIG.EXPIRING_COLOR or 
         button_color == CONFIG.NEUTRAL_COLOR then
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

addButton = function(title, affect, command)
  if title == nil or Trim(title) == "" then
    title = utils.inputbox("Enter a title for the new button.", "Button Title")
    if title == nil or title == "" then return end
  end

  title = Trim(title)

  for _, button in ipairs(BUTTONS) do
    if button.title == title or title == "All Favorites" then
      Note("A button with that title already exists!")
      return
    end
  end

  if affect == nil then
    affect = utils.inputbox("The affect this button should represent and track. (optional)", "Button Affect")
  end

  if affect == nil then return end

  if command == nil then
    command = utils.inputbox("The command this button should perform when clicked. (optional)", "Button Command")
  end

  if command == nil then return end
  
  BUTTONS[#BUTTONS + 1] = {
    affect = affect,
    title = title,
    action = command
  }

  draw()
  save()
  Note("Button '" .. title .. "' has been added!")
end

editButton = function(title, new_affect, new_command)
  if title == nil or Trim(title) == "" then
    Note("You must specify the name of the button you wish to edit.")
    return
  end

  title = Trim(title)

  if title:lower() == Trim(CONFIG.CAST_FAVORITES_LABEL:lower()) then 
    Note("You can't edit that button with the edit command.")
    return
  end

  for _, button in ipairs(BUTTONS) do
    if Trim(button.title:lower()) == title:lower() then
      title = button.title
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

      draw()
      save()
      if title:lower() ~= button.title:lower() then title = button.title .. " (formerly '" .. title .. "')" end
      Note("Button '" .. title .. "' has been changed!")
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

renameButton = function(old_name, new_name)
  if old_name == nil or Trim(old_name) == "" then
    Note("You must specify the name of the button you wish to rename.")
    return
  end

  old_name = Trim(old_name)

  if old_name:lower() == Trim(CONFIG.CAST_FAVORITES_LABEL:lower()) then 
    Note("You can rename this button in the configuration window.")
    return
  end

  for _, button in ipairs(BUTTONS) do
    if Trim(button.title:lower()) == Trim(old_name:lower()) then
      if new_name == nil or Trim(new_name) == "" then
        new_name = utils.inputbox("Choose a new name.", "Button Rename", old_name)
        if new_name == nil or Trim(new_name) == "" or new_name == old_name then
          return
        end
      end

      button.title = Trim(new_name)

      draw()
      save()
      Note("Button '" .. old_name .. "' has been changed to '" .. new_name .. "'")
      return
    end
  end

  Note("Button '" .. old_name .. "' doesn't exist!")
end

deleteButton = function(title)
  if title == nil or Trim(title) == "" then
    Note("You must specify the name of the button you wish to delete.")
    return
  end

  title = Trim(title)

  if title:lower() == Trim(CONFIG.CAST_FAVORITES_LABEL:lower()) then 
    Note("You can't delete that button, hide it from the configuration window.")
    return
  end

  for i, button in ipairs(BUTTONS) do
    if Trim(button.title:lower()) == title:lower() then
      title = button.title
      table.remove(BUTTONS, i)
      draw()
      save()
      Note("Button '" .. title .. "' has been removed!")
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

moveButtonUp = function(title)
  if title == nil or Trim(title) == "" then
    Note("You must specify the name of the button you wish to move.")
    return
  end

  title = Trim(title)

  if title:lower() == Trim(CONFIG.CAST_FAVORITES_LABEL:lower()) then 
    Note("You can't move that button.")
    return
  end

  local index = nil
  for i, button in ipairs(BUTTONS) do
    if Trim(button.title:lower()) == title:lower() then
      title = button.title
      index = i
      break
    end
  end

  if index and index > 1 then
    BUTTONS[index], BUTTONS[index - 1] = BUTTONS[index - 1], BUTTONS[index]
    draw()
    save()
    Note("Button '" .. title .. "' has been moved up!")
    return
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

moveButtonDown = function(title)
  if title == nil or Trim(title) == "" then
    Note("You must specify the name of the button you wish to move.")
    return
  end

  title = Trim(title)

  if title:lower() == Trim(CONFIG.CAST_FAVORITES_LABEL:lower()) then 
    Note("You can't move that button.")
    return
  end

  local index = nil
  for i, button in ipairs(BUTTONS) do
    if Trim(button.title:lower()) == title:lower() then
      index = i
      break
    end
  end

  if index and index < #BUTTONS then
    BUTTONS[index], BUTTONS[index + 1] = BUTTONS[index + 1], BUTTONS[index]
    draw()
    save()
    Note("Button '" .. title .. "' has been moved down!")
    return
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

toggleFavorite = function(title)
  if title == nil or title:lower() == "all favorites" then return end

  for _, button in ipairs(BUTTONS) do
    if button.title == title then
      button.favorite = not button.favorite

      draw()
      save()
      if button.favorite then
        Note("Button '" .. title .. "' has been set as a favorite!")
      else
        Note("Button '" .. title .. "' has been removed as a favorite.")
      end
      return
    end
  end

  Note("Button '" .. title .. "' doesn't exist!")
end

toggleBroadcast = function(affect)
  if BROADCAST == nil then BROADCAST = {} end
  if not affect or Trim(affect) == "" then
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
  else
    local broadcasting = BROADCAST[affect] or false
    BROADCAST[affect] = not broadcasting

    if BROADCAST[affect] then Note("Losing and gaining '" .. affect .. "' will be broadcast.") 
    else Note("Losing and gaining '" .. affect .. "' will NOT be broadcast.") end

    save()
  end
end

getDuration = function(affect)
  return DURATIONS[affect]
end

isAutoUpdateEnabled = function()
  return CONFIG ~= nil and CONFIG.AUTOUPDATE
end

return {
  Prepare = prepare,
  Initialize = initialize,
  Draw = draw,
  Clear = clear,
  Close = close,
  Save = save,
  SetAffect = setAffect,
  RemoveAffect = removeAffect,
  GetConfiguration = getConfiguration,
  OnConfigureDone = onConfigureDone,
  CastFavorites = castFavorites,
  AddButton = addButton,
  EditButton = editButton,
  RenameButton = renameButton,
  DeleteButton = deleteButton,
  MoveButtonUp = moveButtonUp,
  MoveButtonDown = moveButtonDown,
  ToggleFavorite = toggleFavorite,
  ToggleBroadcast = toggleBroadcast,
  GetDuration = getDuration,
  IsAutoUpdateEnabled = isAutoUpdateEnabled
}
