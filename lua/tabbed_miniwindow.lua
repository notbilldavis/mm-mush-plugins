local serializer_installed, serialization_helper = pcall(require, "serializationhelper")
local config_installed, config_window = pcall(require, "configuration_miniwindow")
local const_installed, consts = pcall(require, "consthelper")

local WIN = GetPluginID()
local FONT = WIN .. "_capture_font"
local HEADERFONT = WIN .. "_header_font"

local prepare, initialize, capture, getDateString, close, isAutoUpdateEnabled, onConfigureDone, doDebug
local load, save, create, draw, drawNotifications, addLineToTab, onScrollToBottom, drawWindow, drawTabs, drawLines,
  drawScrollbar, drawResizeHandle, drawScrollToBottom, addTextToBuffer, clearTab, formatLines, populateSizes,
  setSizeConst, renderRectangle, drawNotification, drawDragHandle, drawNotifications, drawSelection, hasSelection,
  drawScrollbar, drawScrollbarDetails, drawResizeHandle, moveScrollBar, doRightClickHeaderMenu, doRightClickMenu,
  showUnlockedRightClick, roundToNearestCharacter, copySelectedText, configure, addNewTab, adjustAnchor,
  getSubstringByPixelRange, captureText, addStyledLine, shouldSkip, calculateOptimalWindowLines

local CONFIG = nil
local POSITION = nil

local STYLES = nil
local LINE_HEIGHT = nil
local HEADER_HEIGHT = 0
local LAST_REFRESH = 0

local CHARACTER_NAME = ""
local ALL_TABS = { }
local CURRENT_TAB_NAME = "Captures"
local TEXT_BUFFERS = { all = {} }
local FORMATTED_LINES = { all = {} }
local SCROLL_OFFSETS = { all = 0 }
local UNREAD_COUNT = { all = 0 }
local PREINIT_LINES = { }
local SELECTIONS = { all = { start_x = nil, start_y = nil, end_x = nil, end_y = nil } }

local DRAG_SCROLLING = false
local IS_SELECTING = false
local CHARACTER_WIDTH = 0
local LAST_SELECTION = nil
local SELECTED_TEXT = ""
local IS_RESIZING = false
local IS_DRAGGING = false
local RESIZE_DRAG_X = nil
local RESIZE_DRAG_Y = nil
local START_DRAG_Y = 0
local START_DRAG_OFFSET = 0
local SIZES = {}
local INIT = false

local ANCHOR_LIST = { 
  [1] = "Top Left (Window)", [2] = "Bottom Left (Window)", [3] = "Top Right (Window)", [4] = "Bottom Right (Window)", 
  [5] = "Top Fit Width (Output)", [6] = "Bottom Fit Width (Output)", [7] = "Right Top (Output)", [8] = "Left Top (Output)",
  [9] = "Right Bottom (Output)", [10] = "Left Bottom (Output)"
}

local STRETCH_LIST = {
  [1] = "Horizontal (Window)", [2] = "Vertical (Window)", [3] = "Horizontal (Output)", [4] = "Vertical (Output)"
}

local POSSIBLE_CHANNELS = {
  affects = true, alliance = true, announce = true, archon = true, auction = true, aucverb = true, clan = true, 
  form = true, notify = true, novice = true, page = true, relay = true, say = true, shout = true, talk = true, 
  tell = true, yell = true, betters = true
}

local GAGS = {
  shout = { 
    "Shop the fine wares at the Alyrian Bazaar", 
    "Hear ye, hear ye, adventurers of", 
    "back from a long absence!" 
  },
  yell = {
    "available in Agatha's Shoppe of Illusions!",
    "A masculine voice yells",
    "Ferry is now docked at",
    "The ship Merdraco be docked at",
    "Step right up, step right up!",
    "If you'd like information on quests, please visit me at the Shrine of St. Wisehart!",
    "Unbreakable, level-scaling weapons for sale in the village's main street, near the Shrine!",
    "Come visit the Crystal Guild's hall near the cemetery",
    "Attention! Get your nefarious wares at the Xaltian Bazaar!"
  },
  say = {
    "[CLAN]",
    " clan members heard you say, '"
  },
  tell = {
    "'I don't know any skills in which I could train you.'"
  }
}

local SERIALIZE_TAGS = {
  LAST_CONFIG = "last_capture_config", CONFIG = "_capture_config", 
  TABS = "_all_tabs", POSITION = "_capture_position"
}

local refresh_type = { NONE = 1, NOTIFICATIONS = 2, ALL = 3 }

prepare = function()
  INIT = false
  CHARACTER_NAME = nil
  CONFIG = { TIME_24 = true }
  local last_config = serialization_helper.GetSerializedVariable(SERIALIZE_TAGS.LAST_CONFIG)
  if last_config.left ~= nil then
    WindowCreate(WIN, last_config.left, last_config.top, last_config.width, last_config.height, 12, 2, 0)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, last_config.width, last_config.height, 0)
    WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, last_config.border)
    CONFIG = { TIME_24 = last_config.time_24 }
    WindowShow(WIN, true)
  end
end

initialize = function(character_name)
  CHARACTER_NAME = character_name

  load()
  create()
  INIT = true
  if #PREINIT_LINES > 0 then
    for i = 1, #PREINIT_LINES do
      addStyledLine(PREINIT_LINES[i].channel, PREINIT_LINES[i].segments)
    end
    PREINIT_LINES = {}
  else
    draw()
  end
end

capture = function(trigger_style_runs, line, chan)
  if shouldSkip(chan, line) then return end

  captureText("silver", "black", "[".. getDateString() .. "] ", chan)

  for i = 1, #trigger_style_runs do
    local txt = trigger_style_runs[i].text

    if txt:find("Novice") then
      txt = txt:gsub("%[CLAN Novice Adventurers%]", "%[Novice%]")
      txt = txt:gsub("Novice clan members", "Novices")
      txt = txt:gsub("Novice clan member", "Novice")
    end

    if txt:find("Vandemaar's Magic Mirror") then
      txt = txt:gsub("^You hear (.+) say through Vandemaar's Magic Mirror:", "%(mirror%) %1:")
    end

    local fgcol = trigger_style_runs[i].textcolour
    local bgcol = trigger_style_runs[i].backcolour
    
    if type(trigger_style_runs[i].textcolour) == "number" then
      fgcol = RGBColourToName(trigger_style_runs[i].textcolour)
      bgcol = RGBColourToName(trigger_style_runs[i].backcolour)
    end    

    captureText(fgcol, bgcol, txt, chan)
  end

  captureText("silver", "black", "\r\n", chan)  
end

captureText = function(fgcol, bgcol, txt, type)
  if (not STYLES) then
    STYLES = {}
  end

  if (txt == "\r\n") then
    addStyledLine(type, STYLES)
    STYLES = {}
  else
    STYLES[#STYLES + 1] = {
      text = txt,
      textcolour = ColourNameToRGB(fgcol),
      backcolour = ColourNameToRGB(bgcol)
    }
  end
end

shouldSkip = function(channel, line)
  if GAGS[channel] ~= nil then    
    for i = 1, #GAGS[channel] do
      if line:lower():find(GAGS[channel][i]:lower(), 1, true) then
        return true
      end
    end
  end
  return false
end

addStyledLine = function(channel, styledLineSegments)
  if not INIT then
    table.insert(PREINIT_LINES, { channel = channel, segments = styledLineSegments })
    return
  end

  local currentOffset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local formattedLines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local was_at_bottom = #formattedLines <= currentOffset + CONFIG.WINDOW_LINES + 1
  local refresh = refresh_type.NONE
  local notifications = {}

  for i = 1, #ALL_TABS do
    refresh = math.max(addLineToTab(ALL_TABS[i], channel, styledLineSegments), refresh)    
  end

  if UNREAD_COUNT[CURRENT_TAB_NAME] == nil or UNREAD_COUNT[CURRENT_TAB_NAME] > 0 then
    UNREAD_COUNT[CURRENT_TAB_NAME] = 0
  end

  if refresh == refresh_type.ALL then
    if was_at_bottom then
      onScrollToBottom()
    else
      draw()
    end
  elseif refresh == refresh_type.NOTIFICATIONS then
    drawNotifications()
  end
end

load = function()
  CONFIG = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG)
  ALL_TABS = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.TABS)
  POSITION = serialization_helper.GetSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION)

  if CONFIG.WINDOW_LINES == nil and POSITION.WINDOW_HEIGHT ~= nil then
    local tf1, tf2 = FONT .. "_temp", HEADERFONT .. "_temp"
    WindowFont(WIN, tf1, CONFIG.CAPTURE_FONT.name, CONFIG.CAPTURE_FONT.size)
    WindowFont(WIN, tf2, CONFIG.HEADER_FONT.name, CONFIG.HEADER_FONT.size)
    local lh, hh = WindowFontInfo(WIN, tf1, 1), WindowFontInfo(WIN, tf2, 1) + 10
    local text_area_height = POSITION.WINDOW_HEIGHT - hh - consts.GetBorderWidth() * 3
    CONFIG.WINDOW_LINES = math.floor(text_area_height / lh)
  end

  CONFIG.CAPTURE_FONT = serialization_helper.GetValueOrDefault(CONFIG.CAPTURE_FONT, { name = "Lucida Console", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.HEADER_FONT = serialization_helper.GetValueOrDefault(CONFIG.HEADER_FONT, { name = "Lucida Console", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.LOCK_POSITION = serialization_helper.GetValueOrDefault(CONFIG.LOCK_POSITION, false)
  CONFIG.SCROLL_WIDTH = serialization_helper.GetValueOrDefault(CONFIG.SCROLL_WIDTH, 15)
  CONFIG.MAX_LINES = serialization_helper.GetValueOrDefault(CONFIG.MAX_LINES, 1000)
  CONFIG.WINDOW_LINES = serialization_helper.GetValueOrDefault(CONFIG.WINDOW_LINES, 15)
  CONFIG.NOTIFICATION_COLOR = serialization_helper.GetValueOrDefault(CONFIG.NOTIFICATION_COLOR, ColourNameToRGB("red"))
  CONFIG.BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BORDER_COLOR, ColourNameToRGB("silver"))
  CONFIG.ACTIVE_COLOR = serialization_helper.GetValueOrDefault(CONFIG.ACTIVE_COLOR, ColourNameToRGB("darkgreen"))
  CONFIG.INACTIVE_COLOR = serialization_helper.GetValueOrDefault(CONFIG.INACTIVE_COLOR, ColourNameToRGB("grey"))
  CONFIG.DETAIL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DETAIL_COLOR, ColourNameToRGB("gray"))
  CONFIG.DETAIL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DETAIL_COLOR, ColourNameToRGB("silver"))
  CONFIG.DETAIL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DETAIL_COLOR, ColourNameToRGB("silver"))
  CONFIG.SCROLL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.SCROLL_COLOR, ColourNameToRGB("darkgray"))
  CONFIG.BACKGROUND_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BACKGROUND_COLOR, ColourNameToRGB("black"))
  CONFIG.Z_POSITION = serialization_helper.GetValueOrDefault(CONFIG.Z_POSITION, 500)
  CONFIG.TIME_24 = serialization_helper.GetValueOrDefault(CONFIG.TIME_24, true)
  CONFIG.AUTOUPDATE = serialization_helper.GetValueOrDefault(CONFIG.AUTOUPDATE, true)

  local default_tab = {
    name = "Captures", 
    channels = { 
      alliance = true, announce = true, archon = true, clan = true, form = true, notify = true, affects = true,
      novice = true, page = true, relay = true, shout = true, talk = true, tell = true, yell = true, betters = true,
    },
    notify = true
  }

  ALL_TABS[1] = serialization_helper.GetValueOrDefault(ALL_TABS[1], default_tab)
  CURRENT_TAB_NAME = ALL_TABS[1]["name"] or ""

  POSITION.WINDOW_HEIGHT = consts.GetBorderWidth() * 3 + 10 + CONFIG.WINDOW_LINES * 10
  POSITION.WINDOW_WIDTH = serialization_helper.GetValueOrDefault(POSITION.WINDOW_WIDTH, consts.GetClientWidth() - consts.GetOutputRightOutside())
  POSITION.WINDOW_LEFT = serialization_helper.GetValueOrDefault(POSITION.WINDOW_LEFT, consts.GetOutputRightOutside())
  POSITION.WINDOW_TOP = serialization_helper.GetValueOrDefault(POSITION.WINDOW_TOP, consts.GetOutputBottomOutside() - POSITION.WINDOW_HEIGHT)
end

create = function()
  local capfont = CONFIG["CAPTURE_FONT"]
  local hdrfont = CONFIG["HEADER_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, FONT, capfont.name, capfont.size, 
    serialization_helper.ConvertToBool(capfont.bold), 
    serialization_helper.ConvertToBool(capfont.italic), 
    serialization_helper.ConvertToBool(capfont.italic), 
    serialization_helper.ConvertToBool(capfont.strikeout))

  WindowFont(WIN, HEADERFONT, hdrfont.name, hdrfont.size, 
    serialization_helper.ConvertToBool(hdrfont.bold), 
    serialization_helper.ConvertToBool(hdrfont.italic), 
    serialization_helper.ConvertToBool(hdrfont.italic), 
    serialization_helper.ConvertToBool(hdrfont.strikeout))

  CHARACTER_WIDTH = WindowTextWidth(WIN, FONT, "X")
  LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1)
  HEADER_HEIGHT = WindowFontInfo(WIN, HEADERFONT, 1) + 10
  
  POSITION.WINDOW_HEIGHT = consts.GetBorderWidth() * 3 + HEADER_HEIGHT + CONFIG.WINDOW_LINES * LINE_HEIGHT
end

draw = function()
  if not INIT then return end
    
  WindowShow(WIN, false)

  drawWindow()
  drawTabs()
  drawLines()
  drawScrollbar()
  drawResizeHandle()
  drawScrollToBottom()

  WindowShow(WIN, true)
end

addLineToTab = function(tab, channel, styledLineSegments)
  if tab == nil or tab["channels"] == nil or tab["name"] == nil or tab["name"] == "" then
    return refresh_type.NONE
  end

  if tab["channels"][channel] then
    local tab_name = tab["name"] or ""
    addTextToBuffer(tab_name, styledLineSegments)
    
    local ref = refresh_type.NONE
    if tab["notify"] then ref = refresh_type.NOTIFICATIONS end
    if tab_name == CURRENT_TAB_NAME then ref = refresh_type.ALL end
    if ref ~= refresh_type.NONE then
      local cnt = UNREAD_COUNT[tab_name] or 0
      UNREAD_COUNT[tab_name] = cnt + 1
      return ref
    end
  end

  return refresh_type.NONE
end

addTextToBuffer = function(name, segments)
  if TEXT_BUFFERS[name] == nil then 
    clearTab(name)
  end

  table.insert(TEXT_BUFFERS[name], segments)

  if #TEXT_BUFFERS[name] > CONFIG.MAX_LINES then
    table.remove(TEXT_BUFFERS[name], 1)
  end

  if name == CURRENT_TAB_NAME then
    formatLines(name)
  end
end

formatLines = function(list)
  if TEXT_BUFFERS[list] == nil then return end

  local maxWidth = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH - 8 - consts.GetBorderWidth() * 2

  FORMATTED_LINES[list] = {}    

  for _, styles in ipairs(TEXT_BUFFERS[list]) do
    local wrapped = {}
    local currentLine = {}
    local currentWidth = 0

    for _, seg in ipairs(styles) do
      local text = seg.text
      local textcolour = seg.textcolour or "white"
      local backcolour = seg.backcolour or "black"

      if text ~= nil then
        while #text > 0 do
          local remaining = text
          local fit = ""

          for i = 1, #remaining do
            local candidate = string.sub(remaining, 1, i)
            local width = WindowTextWidth(WIN, FONT, candidate)

            if currentWidth + width > maxWidth then
              break
            end

            fit = candidate
          end

          if fit == "" then
            fit = string.sub(remaining, 1, 1)
          end

          table.insert(currentLine, { text = fit, textcolour = textcolour, backcolour = backcolour })
          currentWidth = currentWidth + WindowTextWidth(WIN, FONT, fit)
          text = string.sub(text, #fit + 1)

          if currentWidth >= maxWidth then
            table.insert(wrapped, currentLine)
            currentLine = {}
            currentWidth = 0
          end
        end
      end
    end

    if #currentLine > 0 then
      table.insert(wrapped, currentLine)
    end

    for _, line in ipairs(wrapped) do
      table.insert(FORMATTED_LINES[list], line)
    end
  end
end

drawWindow = function()
  populateSizes()

  WindowPosition(WIN, POSITION.WINDOW_LEFT, POSITION.WINDOW_TOP, 4, 2)
  WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, CONFIG.BACKGROUND_COLOR)
  WindowSetZOrder(WIN, CONFIG.Z_POSITION)

  renderRectangle(SIZES.ENTIRE_WINDOW, consts.GetBorderWidth())

  WindowDeleteAllHotspots(WIN)

  WindowAddHotspot(WIN, "textarea", 0, HEADER_HEIGHT + 2, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_HEIGHT - 2, "", "", "OnTextAreaMouseDown", "", "OnTextAreaMouseUp", "", miniwin.cursor_ibeam, 0)  
  WindowDragHandler(WIN, "textarea", "OnTextAreaMouseMove", "", 0x10)
  WindowScrollwheelHandler(WIN, "textarea", "OnWheel")  
end

populateSizes = function()
  SIZES.ENTIRE_WINDOW = setSizeConst(0, 0, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, CONFIG.BACKGROUND_COLOR)
  SIZES.TEXT_AREA = setSizeConst(consts.GetBorderWidth(), HEADER_HEIGHT + consts.GetBorderWidth(), POSITION.WINDOW_WIDTH - consts.GetBorderWidth() - CONFIG.SCROLL_WIDTH - 1, POSITION.WINDOW_HEIGHT - consts.GetBorderWidth(), CONFIG.BACKGROUND_COLOR)

  local header_right = POSITION.WINDOW_WIDTH - consts.GetBorderWidth()
  local scroll_bottom = POSITION.WINDOW_HEIGHT - consts.GetBorderWidth()

  if not CONFIG.LOCK_POSITION then
    header_right = header_right - CONFIG.SCROLL_WIDTH
    scroll_bottom = scroll_bottom - CONFIG.SCROLL_WIDTH

    SIZES.DRAG_HANDLE = setSizeConst(header_right, consts.GetBorderWidth() + 1, POSITION.WINDOW_WIDTH - consts.GetBorderWidth() - 1, HEADER_HEIGHT - 2, CONFIG.BACKGROUND_COLOR)
    SIZES.RESIZE_HANDLE = setSizeConst(header_right, POSITION.WINDOW_HEIGHT - consts.GetBorderWidth() - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_WIDTH - consts.GetBorderWidth() - 1, POSITION.WINDOW_HEIGHT - consts.GetBorderWidth() - 1, CONFIG.BACKGROUND_COLOR)
  end

  SIZES.ENTIRE_HEADER = setSizeConst(consts.GetBorderWidth(), consts.GetBorderWidth(), header_right, HEADER_HEIGHT - consts.GetBorderWidth() * 2, CONFIG.BACKGROUND_COLOR)
  SIZES.SINGLE_TAB = setSizeConst(consts.GetBorderWidth(), consts.GetBorderWidth(), 20, HEADER_HEIGHT, ColourNameToRGB("cyan"))
  SIZES.ENTIRE_SCROLL = setSizeConst(POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH - consts.GetBorderWidth(), HEADER_HEIGHT + consts.GetBorderWidth(), POSITION.WINDOW_WIDTH - consts.GetBorderWidth() - 1, scroll_bottom - 1, CONFIG.DETAIL_COLOR)
  SIZES.SCROLL_SLIDER = setSizeConst(SIZES.ENTIRE_SCROLL.LEFT + 5, SIZES.ENTIRE_SCROLL.TOP + CONFIG.SCROLL_WIDTH, SIZES.ENTIRE_SCROLL.RIGHT - 5, scroll_bottom - CONFIG.SCROLL_WIDTH - 1, CONFIG.BACKGROUND_COLOR)
  SIZES.SCROLL_TOP = setSizeConst(SIZES.ENTIRE_SCROLL.LEFT, SIZES.ENTIRE_SCROLL.TOP, SIZES.ENTIRE_SCROLL.RIGHT, SIZES.ENTIRE_SCROLL.TOP + CONFIG.SCROLL_WIDTH, CONFIG.BACKGROUND_COLOR)
  SIZES.SCROLL_BOTTOM = setSizeConst(SIZES.ENTIRE_SCROLL.LEFT, SIZES.ENTIRE_SCROLL.BOTTOM - CONFIG.SCROLL_WIDTH, SIZES.ENTIRE_SCROLL.RIGHT, SIZES.ENTIRE_SCROLL.BOTTOM, CONFIG.BACKGROUND_COLOR)
  SIZES.SCROLL_THUMB = setSizeConst(POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH - consts.GetBorderWidth() - 1, HEADER_HEIGHT + consts.GetBorderWidth() * 2 + CONFIG.SCROLL_WIDTH + 1, POSITION.WINDOW_WIDTH - consts.GetBorderWidth(), scroll_bottom, CONFIG.SCROLL_COLOR)
end

setSizeConst = function(left, top, right, bottom, color)
  local sizeConst = {}
  sizeConst.LEFT = left
  sizeConst.TOP = top
  sizeConst.RIGHT = right
  sizeConst.BOTTOM = bottom
  sizeConst.COLOR = color
  sizeConst.WIDTH = right - left
  sizeConst.HEIGHT = bottom - top
  return sizeConst
end

drawTabs = function()
  local x = consts.GetBorderWidth()
  for idx, tab in ipairs(ALL_TABS) do
    local tab_name = tab["name"] or ""
    if tab_name ~= "" then
      local text_width = WindowTextWidth(WIN, HEADERFONT, tab_name)
      local tab_color = (tab_name == CURRENT_TAB_NAME) and CONFIG.ACTIVE_COLOR or CONFIG.INACTIVE_COLOR
      local center_pos_x = x + ((text_width + 20) / 2) - (text_width / 2)
      local center_pos_y = (HEADER_HEIGHT - WindowFontInfo(WIN, HEADERFONT, 1)) / 2 + consts.GetBorderWidth()
      local tab_tooltip = ""

      SIZES.SINGLE_TAB.LEFT = x
      SIZES.SINGLE_TAB.RIGHT = x + text_width + 20
      SIZES.SINGLE_TAB.COLOR = tab_color
      renderRectangle(SIZES.SINGLE_TAB, 1, CONFIG.BORDER_COLOR)
      WindowText(WIN, HEADERFONT, tab_name, center_pos_x, center_pos_y, 0, 0, CONFIG.HEADER_FONT.colour)

      if tab["notify"] then
        drawNotification(tab_name, x + text_width)
      end

      WindowLine(WIN, SIZES.ENTIRE_HEADER.LEFT, HEADER_HEIGHT, POSITION.WINDOW_WIDTH - consts.GetBorderWidth(), HEADER_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, consts.GetBorderWidth())
      
      WindowAddHotspot(WIN, tab_name, x, 0, x + text_width + 20, HEADER_HEIGHT, "", "", "", "", "OnHeaderClick", tab_tooltip, miniwin.cursor_hand, 0)

      x = x + text_width + 25
    end
  end

  if not CONFIG.LOCK_POSITION then
    drawDragHandle()
  end
end

drawNotifications = function()
  local x = SIZES.ENTIRE_HEADER.LEFT
  for idx, tab in ipairs(ALL_TABS) do
    local tab_name = tab["name"] or ""
    if tab_name ~= "" then
      local text_width = WindowTextWidth(WIN, HEADERFONT, tab_name)
    
      if tab["notify"] then
        drawNotification(tab_name, x + text_width)
      end

      x = x + text_width + 25
    end
  end
end

drawNotification = function(tab_name, x)
  local cnt = UNREAD_COUNT[tab_name] or 0
  if cnt > 0 then
    WindowCircleOp(WIN, miniwin.circle_ellipse, x + 12, HEADER_HEIGHT / 2 - consts.GetBorderWidth(), x + 16, HEADER_HEIGHT / 2 - consts.GetBorderWidth() + 4, 
      CONFIG.NOTIFICATION_COLOR, miniwin.pen_solid, 1, CONFIG.NOTIFICATION_COLOR, miniwin.brush_solid)
    WindowHotspotTooltip(WIN, tab_name, cnt .. " unread")
  end  
end

drawLines = function()
  renderRectangle(SIZES.TEXT_AREA)
    
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local y = SIZES.TEXT_AREA.TOP + 2

  SELECTED_TEXT = ""

  for i = offset + 1, #lines do
    if y + LINE_HEIGHT > SIZES.TEXT_AREA.BOTTOM then
      if offset >= #lines - CONFIG.WINDOW_LINES then
        Note("The capture window is trying to display lines off the screen, configure the font settings and size.")
      end
      break
    end

    local segments = lines[i]
    local x = SIZES.TEXT_AREA.LEFT + 2
    for _, s in ipairs(segments) do
      local w = WindowTextWidth(WIN, FONT, s.text)

      drawSelection(x, y, w, offset, s)

      WindowText(WIN, FONT, s.text, x, y, 0, 0, s.textcolour)
      x = x + w
    end
    y = y + LINE_HEIGHT
  end
end

drawSelection = function(x, y, w, offset, s)
  local selection = SELECTIONS[CURRENT_TAB_NAME]
  if not hasSelection(selection) then return end

  local drawing_line = math.floor((y - HEADER_HEIGHT + 2) / LINE_HEIGHT) + offset + 1
  local bg_color = CONFIG.BACKGROUND_COLOR
  if s.backcolour ~= nil and s.backcolour ~= "" then
    bg_color = ColourNameToRGB(s.backcolour)
  end

  WindowRectOp(WIN, miniwin.rect_fill, x, y, x + w, y + LINE_HEIGHT, bg_color)

  if drawing_line >= selection.starting_line and drawing_line <= selection.ending_line then
    local reverse_x = selection.start_x > selection.end_x -- right to left
    local reverse_y = selection.start_y > selection.end_y -- bottom to top
    local low_x = math.min(selection.start_x, selection.end_x)
    local high_x = math.max(selection.start_x, selection.end_x)
    
    if selection.starting_line ~= selection.ending_line then
      if drawing_line == selection.starting_line then 
        high_x = x + w
        if reverse_y then low_x = selection.end_x
        else low_x = selection.start_x end
      elseif drawing_line == selection.ending_line then 
        low_x = x 
        if reverse_y then high_x = selection.start_x
        else high_x = selection.end_x end
      else
        low_x = x
        high_x = x + w
      end

      if (low_x > high_x) then return end
    end

    if (high_x >= x and high_x <= x + w) or (low_x >= x and low_x <= x + w) then
      local final_start_x, final_end_x = math.max(x, low_x), math.min(x + w, high_x)
      WindowRectOp(WIN, miniwin.rect_fill, final_start_x, y, final_end_x, y + LINE_HEIGHT, ColourNameToRGB("dimgray"))

      local start_idx = (final_start_x - x) / CHARACTER_WIDTH + 1
      local end_idx = (final_end_x - x) / CHARACTER_WIDTH
      SELECTED_TEXT = SELECTED_TEXT .. s.text:sub(start_idx, end_idx)
    end
  end
end

hasSelection = function(s)
  if s == nil then s = SELECTIONS[CURRENT_TAB_NAME] end
  return s ~= nil and s.start_x ~= nil and s.start_y ~= nil and s.end_x ~= nil and s.end_y ~= nil 
    and (s.start_x - s.end_x >= CHARACTER_WIDTH or s.end_x - s.start_x >= CHARACTER_WIDTH or s.start_y - s.end_y >= CHARACTER_WIDTH or s.end_y - s.start_y >= CHARACTER_WIDTH)
end

drawScrollbar = function()
  renderRectangle(SIZES.ENTIRE_SCROLL)
  renderRectangle(SIZES.SCROLL_SLIDER)
  renderRectangle(SIZES.SCROLL_TOP, 1)
  renderRectangle(SIZES.SCROLL_BOTTOM, 1)
  
  local current_offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local formattedLines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local total_lines = #formattedLines  
  local maxScroll = total_lines - CONFIG.WINDOW_LINES
  local thumbsize = math.min(SIZES.SCROLL_SLIDER.HEIGHT, math.max(10, SIZES.SCROLL_SLIDER.HEIGHT * (CONFIG.WINDOW_LINES / (total_lines))))
  local scrollRatio = current_offset / math.max(maxScroll, 1)

  SIZES.SCROLL_THUMB.TOP = (scrollRatio * (SIZES.SCROLL_SLIDER.HEIGHT - thumbsize)) + SIZES.SCROLL_SLIDER.TOP
  SIZES.SCROLL_THUMB.BOTTOM = SIZES.SCROLL_THUMB.TOP + thumbsize

  drawScrollbarDetails()

  renderRectangle(SIZES.SCROLL_THUMB, 1, CONFIG.BACKGROUND_COLOR)

  if not DRAG_SCROLLING then
    WindowAddHotspot(WIN, "up", SIZES.SCROLL_TOP.LEFT, SIZES.SCROLL_TOP.TOP, SIZES.SCROLL_TOP.RIGHT, SIZES.SCROLL_TOP.BOTTOM, "", "", "ScrollArrowsMouseDown", "", "", "", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, "down", SIZES.SCROLL_BOTTOM.LEFT, SIZES.SCROLL_BOTTOM.TOP, SIZES.SCROLL_BOTTOM.RIGHT, SIZES.SCROLL_BOTTOM.BOTTOM, "", "", "ScrollArrowsMouseDown", "", "", "",  miniwin.cursor_hand, 0)

    WindowAddHotspot(WIN, "scroll_thumb", SIZES.SCROLL_THUMB.LEFT, SIZES.SCROLL_THUMB.TOP, SIZES.SCROLL_THUMB.RIGHT, SIZES.SCROLL_THUMB.BOTTOM, 
      "", "", "OnScrollThumbDragStart", "", "", "", miniwin.cursor_hand, 0)
    WindowDragHandler(WIN, "scroll_thumb", "OnScrollThumbDragMove", "OnScrollThumbDragRelease", 0)
  end
end

function OnScrollThumbDragStart()
  DRAG_SCROLLING = true
  START_DRAG_Y = WindowInfo(WIN, 18)
  START_DRAG_OFFSET = SCROLL_OFFSETS[CURRENT_TAB_NAME]
end

function OnScrollThumbDragMove()
  if DRAG_SCROLLING then
    local mouse_pos_y = WindowInfo(WIN, 18)
    local total_lines = #FORMATTED_LINES[CURRENT_TAB_NAME]
    local scrollable_lines = math.max(total_lines - CONFIG.WINDOW_LINES, 0)
    local delta = mouse_pos_y - START_DRAG_Y
        
    local pixels_per_line = SIZES.SCROLL_SLIDER.HEIGHT / total_lines
    local delta_lines = math.floor(delta / pixels_per_line)
    
    SCROLL_OFFSETS[CURRENT_TAB_NAME] = math.max(0, math.min(scrollable_lines, START_DRAG_OFFSET + delta_lines))
    --Note("d: " .. delta .. ", pl: " .. per_line .. ", dl: " .. delta_lines)
    drawLines()
    drawScrollbar()
  end  
end

function OnScrollThumbDragRelease()
  DRAG_SCROLLING = false
  drawScrollbar()
end

drawScrollbarDetails = function()
  local upArrow = string.format("%i,%i,%i,%i,%i,%i", 
    SIZES.ENTIRE_SCROLL.LEFT + (SIZES.ENTIRE_SCROLL.WIDTH / 3), SIZES.SCROLL_TOP.BOTTOM - (SIZES.ENTIRE_SCROLL.WIDTH / 3),
    SIZES.ENTIRE_SCROLL.LEFT + (SIZES.ENTIRE_SCROLL.WIDTH / 2), SIZES.SCROLL_TOP.TOP + (SIZES.ENTIRE_SCROLL.WIDTH / 3), 
    SIZES.ENTIRE_SCROLL.RIGHT - (SIZES.ENTIRE_SCROLL.WIDTH / 3), SIZES.SCROLL_TOP.BOTTOM - (SIZES.ENTIRE_SCROLL.WIDTH / 3))

  WindowPolygon(WIN, upArrow, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1, CONFIG.DETAIL_COLOR, miniwin.brush_solid, true, false)

  local downArrow = string.format("%i,%i,%i,%i,%i,%i", 
    SIZES.ENTIRE_SCROLL.LEFT + (SIZES.ENTIRE_SCROLL.WIDTH / 3), SIZES.SCROLL_BOTTOM.TOP + (SIZES.ENTIRE_SCROLL.WIDTH / 3), 
    SIZES.ENTIRE_SCROLL.LEFT + (SIZES.ENTIRE_SCROLL.WIDTH / 2), SIZES.SCROLL_BOTTOM.BOTTOM - (SIZES.ENTIRE_SCROLL.WIDTH / 3),
    SIZES.ENTIRE_SCROLL.RIGHT - (SIZES.ENTIRE_SCROLL.WIDTH / 3), SIZES.SCROLL_BOTTOM.TOP + (SIZES.ENTIRE_SCROLL.WIDTH / 3))

  WindowPolygon(WIN, downArrow, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1, CONFIG.DETAIL_COLOR, miniwin.brush_solid, true, false)
end

drawDragHandle = function()
  if not CONFIG.LOCK_POSITION then
    renderRectangle(SIZES.DRAG_HANDLE, 1)
    WindowLine(WIN, SIZES.DRAG_HANDLE.LEFT + 3, SIZES.DRAG_HANDLE.TOP + SIZES.DRAG_HANDLE.HEIGHT / 3, SIZES.DRAG_HANDLE.RIGHT - 3, SIZES.DRAG_HANDLE.TOP + SIZES.DRAG_HANDLE.HEIGHT / 3, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, SIZES.DRAG_HANDLE.LEFT + 3, SIZES.DRAG_HANDLE.TOP + SIZES.DRAG_HANDLE.HEIGHT / 2, SIZES.DRAG_HANDLE.RIGHT - 3, SIZES.DRAG_HANDLE.TOP + SIZES.DRAG_HANDLE.HEIGHT / 2, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, SIZES.DRAG_HANDLE.LEFT + 3, SIZES.DRAG_HANDLE.BOTTOM - SIZES.DRAG_HANDLE.HEIGHT / 3, SIZES.DRAG_HANDLE.RIGHT - 3, SIZES.DRAG_HANDLE.BOTTOM - SIZES.DRAG_HANDLE.HEIGHT / 3, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1)

    WindowAddHotspot(WIN, "drag_" .. WIN, SIZES.DRAG_HANDLE.LEFT, SIZES.DRAG_HANDLE.TOP, SIZES.DRAG_HANDLE.RIGHT, SIZES.DRAG_HANDLE.BOTTOM, "", "", "drag_mousedown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "drag_move", "drag_release", 0)
  end
end

function drag_mousedown(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    IS_DRAGGING = true
    RESIZE_DRAG_X = WindowInfo(WIN, 14)
    RESIZE_DRAG_Y = WindowInfo(WIN, 15)
  elseif flags == miniwin.hotspot_got_rh_mouse then
    showUnlockedRightClick()
  end
end

function drag_move(flags, hotspot_id)
  if IS_DRAGGING then
    local pos_x = clamp(WindowInfo(WIN, 17) - RESIZE_DRAG_X, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH)
    local pos_y = clamp(WindowInfo(WIN, 18) - RESIZE_DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

    SetCursor(miniwin.cursor_hand)
    WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
  end
end

function drag_release(flags, hotspot_id)
  if IS_DRAGGING then
    IS_DRAGGING = false
    POSITION.WINDOW_LEFT = WindowInfo(WIN, 10)
    POSITION.WINDOW_TOP = WindowInfo(WIN, 11)
    save()
    Repaint()
  end
end

drawResizeHandle = function()
  if not CONFIG.LOCK_POSITION then
    renderRectangle(SIZES.RESIZE_HANDLE, 1)
    
    local m = 2
    local n = 2

    while (SIZES.RESIZE_HANDLE.LEFT + m + 2 <= SIZES.RESIZE_HANDLE.RIGHT - 3 and SIZES.RESIZE_HANDLE.TOP + n + 1 <= SIZES.RESIZE_HANDLE.BOTTOM - 4) do
      WindowLine(WIN, SIZES.RESIZE_HANDLE.LEFT + m + 1, SIZES.RESIZE_HANDLE.BOTTOM - 4, SIZES.RESIZE_HANDLE.RIGHT - 3, SIZES.RESIZE_HANDLE.TOP + n, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1)
      WindowLine(WIN, SIZES.RESIZE_HANDLE.LEFT + m + 2, SIZES.RESIZE_HANDLE.BOTTOM - 4, SIZES.RESIZE_HANDLE.RIGHT - 3, SIZES.RESIZE_HANDLE.TOP + n + 1, CONFIG.DETAIL_COLOR, miniwin.pen_solid, 1)
      m = m + 3
      n = n + 3
    end

    WindowAddHotspot(WIN, "resizer", SIZES.RESIZE_HANDLE.LEFT, SIZES.RESIZE_HANDLE.TOP, SIZES.RESIZE_HANDLE.RIGHT, SIZES.RESIZE_HANDLE.BOTTOM, "", "", "OnResizerDown", "", "", "", miniwin.cursor_nw_se_arrow, 0)
    WindowDragHandler(WIN, "resizer", "OnResizerDrag", "OnResizerRelease", 0)
  end  
end

drawScrollToBottom = function()
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0

  if offset + CONFIG.WINDOW_LINES < #lines then
    local left = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH * 4 - GetInfo(277)
    local top = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH * 3 - GetInfo(277)
    local right = left + CONFIG.SCROLL_WIDTH * 2
    local bottom = top + CONFIG.SCROLL_WIDTH * 2

    WindowRectOp(WIN, miniwin.rect_fill, left, top, right, bottom, CONFIG.DETAIL_COLOR)
    
    local centerX = (left + right) / 2
    local point1 = { x = centerX, y = bottom - 10 }
    local point2 = { x = left + 10, y = top + 10 }
    local point3 = { x = right - 10, y = top + 10 }

    local downArrow = string.format("%d,%d,%d,%d,%d,%d", point1.x, point1.y, point2.x, point2.y, point3.x, point3.y)

    WindowPolygon(WIN, downArrow, CONFIG.SCROLL_COLOR, miniwin.pen_solid, 1, CONFIG.DETAIL_COLOR, miniwin.brush_solid, true, false)

    WindowAddHotspot(WIN, "scroll_to_bottom", left, top, right, bottom, "", "", "tabbedcaptures_onScrollToBottom", "", "", "Scroll to bottom", miniwin.cursor_hand, 0)
  end
end

function tabbedcaptures_onScrollToBottom(flags, hotspot_id)
  onScrollToBottom()
end

onScrollToBottom = function()
  local list = CURRENT_TAB_NAME
  local formattedLines = FORMATTED_LINES[list] or {}
  SCROLL_OFFSETS[list] = math.max(0, #formattedLines - CONFIG.WINDOW_LINES)
  draw()
end

-- Scroll handler
function OnWheel(flags, hotspot_id)
  if bit.band(flags, miniwin.wheel_scroll_back) ~= 0 then
    moveScrollBar("down")
  else
    moveScrollBar("up")
  end
end

moveScrollBar = function(direction)
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  
  if direction == "down" then
    offset = math.min(offset + 1, math.max(0, #lines - CONFIG.WINDOW_LINES))
  else
    offset = math.max(0, offset - 1)
  end

  SCROLL_OFFSETS[CURRENT_TAB_NAME] = offset
  draw()
end

function OnHeaderClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if CURRENT_TAB_NAME ~= hotspot_id then
      formatLines(hotspot_id)
    end
    CURRENT_TAB_NAME = hotspot_id
    onScrollToBottom()
    UNREAD_COUNT[hotspot_id] = 0
    draw()
  elseif flags == miniwin.hotspot_got_rh_mouse then
    doRightClickHeaderMenu(hotspot_id)
  end
end

function OnResizerDown(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    IS_RESIZING = true
  elseif flags == miniwin.hotspot_got_rh_mouse then
    showUnlockedRightClick()
  end
end

function OnResizerDrag()
  if IS_RESIZING then
    local mouse_x, mouse_y = GetInfo(283), GetInfo(284)
    
    local new_width = math.max(200, mouse_x - POSITION.WINDOW_LEFT)
    local new_height = math.min(GetInfo(280), math.max(100, mouse_y + POSITION.WINDOW_TOP))

    POSITION.WINDOW_WIDTH = new_width
    POSITION.WINDOW_HEIGHT = new_height

    if (utils.timer() - LAST_REFRESH > 0.0333) then
        WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, 0)
        LAST_REFRESH = utils.timer()
    end
  end
end

function OnResizerRelease()
  if IS_RESIZING then
    save()
    create()
    draw()
    IS_RESIZING = false
  end
end

function ScrollArrowsMouseDown(flags, id)
  moveScrollBar(id)
end

function OnTextAreaMouseDown(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    SELECTIONS[CURRENT_TAB_NAME] = {
      start_x = roundToNearestCharacter(WindowInfo(WIN, 14)) + 5,
      start_y = WindowInfo(WIN, 15)
    }
    IS_SELECTING = true
    --Note("SELECTING")
  end
end

function OnTextAreaMouseUp(flags, hotspot_id)
  if flags == miniwin.hotspot_got_rh_mouse then
    doRightClickMenu()
  else
    --Note("DONE SELECTING")
    IS_SELECTING = false
    local selection = SELECTIONS[CURRENT_TAB_NAME]
    if hasSelection(selection) then
      
    else
      SELECTIONS[CURRENT_TAB_NAME] = nil
    end
    
    draw()
  end
end

doRightClickMenu = function()
  local menu_items = ""
  if not hasSelection() then menu_items = "^" end
  menu_items = menu_items .. "Copy|Clear|-|Configure"

  local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
  if result == "Copy" then
    copySelectedText()
  elseif result == "Clear" then
    FORMATTED_LINES[CURRENT_TAB_NAME] = {}
    TEXT_BUFFERS[CURRENT_TAB_NAME] = {}
    SCROLL_OFFSETS[CURRENT_TAB_NAME] = 0
    draw()
  elseif result == "Configure" then
    configure()
  end
end

doRightClickHeaderMenu = function(name)
  local menu_items = ">Channels | "
  
  for i = 1, #ALL_TABS do
    local tab = ALL_TABS[i]
    if tab["name"] == name then
      for value, _ in pairs(POSSIBLE_CHANNELS) do
        if tab["channels"][value] then
          menu_items = menu_items .. "+" .. value .. " | "
        else
          menu_items = menu_items .. value .. " | "
        end
      end

      menu_items = menu_items .. "< | - | Clear | Mark as Read | - | Rename | New Tab"

      if i <= 1 then menu_items = menu_items .. "^" end
      menu_items = menu_items .. " | Delete Tab"
      
      if tab["notify"] then
        menu_items = menu_items .. " | +Notify"
      else
        menu_items = menu_items .. " | Notify"
      end

      menu_items = menu_items .. "| - | Configure"

      local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)

      if result == "Clear" then
        clearTab(name)
      elseif result == "Mark as Read" then
        UNREAD_COUNT[name] = 0
        draw()

      elseif result == "Rename" then
        local new_name = utils.inputbox(tab["name"] or "", "Rename Tab", name)
        if new_name ~= nil and #new_name > 0 then 
          ALL_TABS[i]["name"] = new_name
          draw()
        end

      elseif result == "New Tab" then
        addNewTab()
      
      elseif result == "Delete Tab" then
        if i > 1 then
          table.remove(ALL_TABS, i)
          draw()
        else
          Note("You can't remove the first tab!")
        end

      elseif result == "Notify" then
        if ALL_TABS[i]["notify"] then
          ALL_TABS[i]["notify"] = nil
        else
          ALL_TABS[i]["notify"] = true
        end
      
      elseif result == "Configure" then
        configure()
        
      elseif result ~= "" then
        if POSSIBLE_CHANNELS[result] then
          if tab["channels"][result] then
            ALL_TABS[i]["channels"][result] = nil
          else
            ALL_TABS[i]["channels"][result] = true
          end

          draw()
        end
      end

      save()

      break;
    end
  end 
end

showUnlockedRightClick = function()
  local menu_items =  "Lock Position | >Anchor | "
  for _, a in ipairs(ANCHOR_LIST) do
    menu_items = menu_items .. a .. " | "
  end
  menu_items = menu_items .. " < | - | Configure"
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
  save()
  draw()
end

copySelectedText = function()
  SetClipboard(SELECTED_TEXT)
  Note("Copied '" .. SELECTED_TEXT .. "' to the clipboard")
end

getSubstringByPixelRange = function(text, startWidth, endWidth)
    local measuredWidth = 0
    local startIndex, endIndex

    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = WindowTextWidth(WIN, FONT, char)
        measuredWidth = measuredWidth + charWidth

        if not startIndex and measuredWidth >= startWidth then
            startIndex = i
        end

        if not endIndex and measuredWidth >= endWidth then
            endIndex = i
            break
        end
    end

    if startIndex then
        return text:sub(startIndex, endIndex or #text)
    else
        return ""
    end
end

save = function()
  local sticky_options = { 
    left = WindowInfo(WIN, 10), top = WindowInfo(WIN, 11), 
    width = WindowInfo(WIN, 3), height = WindowInfo(WIN, 4), 
    border = CONFIG.BORDER_COLOR, time_24 = CONFIG.TIME_24
  }

  serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.LAST_CONFIG, sticky_options)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.CONFIG, CONFIG)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.TABS, ALL_TABS)
  serialization_helper.SaveSerializedVariable(CHARACTER_NAME .. SERIALIZE_TAGS.POSITION, POSITION)
end

getDateString = function()
  if CONFIG == nil or CONFIG.TIME_24 then
    return os.date("%H:%M:%S")
  end
  return os.date("%I:%M:%S %p")  
end

function OnTextAreaMouseMove(flags, hotspot_id)
  if IS_SELECTING then
    local end_x = roundToNearestCharacter(WindowInfo(WIN, 14)) + 5
    local end_y = WindowInfo(WIN, 15)

    SELECTIONS[CURRENT_TAB_NAME].end_x = end_x
    SELECTIONS[CURRENT_TAB_NAME].end_y = end_y

    local selection = SELECTIONS[CURRENT_TAB_NAME]

    SELECTIONS[CURRENT_TAB_NAME].starting_line = consts.clamp(math.floor((math.min(selection.start_y, selection.end_y) - HEADER_HEIGHT + 2) / LINE_HEIGHT) + SCROLL_OFFSETS[CURRENT_TAB_NAME] + 1, 1, #FORMATTED_LINES[CURRENT_TAB_NAME])
    SELECTIONS[CURRENT_TAB_NAME].ending_line = consts.clamp(math.floor((math.max(selection.start_y, selection.end_y) - HEADER_HEIGHT + 2) / LINE_HEIGHT) + SCROLL_OFFSETS[CURRENT_TAB_NAME] + 1, SELECTIONS[CURRENT_TAB_NAME].starting_line, #FORMATTED_LINES[CURRENT_TAB_NAME])

    if LAST_SELECTION == nil or math.abs(LAST_SELECTION.x - end_x) >= CHARACTER_WIDTH or math.abs(LAST_SELECTION.y - end_y) >= CHARACTER_WIDTH / 2 then
      LAST_SELECTION = { x = end_x, y = end_y }
      drawLines()
    end
  end
end

function clearTab(tab) 
  local redraw = tab == CURRENT_TAB_NAME or UNREAD_COUNT[tab] ~= nil

  TEXT_BUFFERS[tab] = {}
  FORMATTED_LINES[tab] = {}
  SCROLL_OFFSETS[tab] = 0
  UNREAD_COUNT[tab] = 0

  if redraw then
    draw()
  end
end

addNewTab = function()
  local new_index = #ALL_TABS + 1
  local channels = {}
  for value, _ in pairs(POSSIBLE_CHANNELS) do
    channels[value] = value
  end
  local new_tab_name = utils.inputbox("Enter a name for the new tab", "New Tab", "Tab " .. new_index)
  if new_tab_name ~= nil and new_tab_name ~= "" then
    local new_tab_channels = utils.multilistbox("Choose the channels this tab will display", "New Tab", channels, nil)
    local new_tab_notify = utils.msgbox("Should new entries added to this tab when it is invactive show a notification icon?", "New Tab", "yesno", "?")
  
    ALL_TABS[new_index] = {
      name = new_tab_name,
      channels = new_tab_channels or {},
      notify = new_tab_notify == "yes"
    }

    draw()
  end
end

roundToNearestCharacter = function(position)
  return position - (position % CHARACTER_WIDTH)
end

close = function()
  WindowShow(WIN, false)
end

isAutoUpdateEnabled = function()
  return CONFIG.AUTOUPDATE
end

function configure()
    local config = {
    Colors = {
      BACKGROUND_COLOR = config_window.CreateColorOption(1, "Background", CONFIG.BACKGROUND_COLOR, "The background color of the entire panel."),
      BORDER_COLOR = config_window.CreateColorOption(2, "Border", CONFIG.BORDER_COLOR, "The border color for the entire panel."),
      ACTIVE_COLOR = config_window.CreateColorOption(3, "Active Tab", CONFIG.ACTIVE_COLOR, "The background color of the active tab." ),
      INACTIVE_COLOR = config_window.CreateColorOption(4, "Inactive Tab", CONFIG.INACTIVE_COLOR, "The background color of the non-active tabs." ),
      SCROLL_COLOR = config_window.CreateColorOption(6, "Scroll Handle", CONFIG.SCROLL_COLOR, "The colors of the scrollbar drag handle." ),
      DETAIL_COLOR = config_window.CreateColorOption(7, "Details", CONFIG.DETAIL_COLOR, "The colors of other details like arrows." ),
    },
    Fonts = {
      CAPTURE_FONT = config_window.CreateFontOption(1, "Capture", CONFIG.CAPTURE_FONT, "The font used to display what is captured, should be the same as output."),
      HEADER_FONT = config_window.CreateFontOption(2, "Header", CONFIG.HEADER_FONT, "The font used for the header titles.")
    },
    Other = {
      LOCK_POSITION = config_window.CreateBoolOption(1, "Lock Position", CONFIG.LOCK_POSITION, "Disable dragging to move the panel."),
      SCROLL_WIDTH = config_window.CreateNumberOption(2, "Scrollbar Width", CONFIG.SCROLL_WIDTH, 5, 50, "The width of the scrollbar."),
      MAX_LINES = config_window.CreateNumberOption(3, "Cached Lines", CONFIG.MAX_LINES, 50, 50000, "The total number of lines to keep before removing them."), 
      TIME_24 = config_window.CreateBoolOption(4, "24-Hour Time", CONFIG.TIME_24, "Show time in 24-hours instead of 12-hour + am/pm."),      
      AUTOUPDATE = config_window.CreateBoolOption(5, "Auto-Update", CONFIG.AUTOUPDATE, "Whether of not this plugin will try to update itself when closing.")
    },
    Position = {
      WINDOW_LEFT = config_window.CreateNumberOption(1, "Left", POSITION.WINDOW_LEFT, 0, consts.GetClientWidth() - POSITION.WINDOW_WIDTH, "The left most position of the entire panel."),
      WINDOW_TOP = config_window.CreateNumberOption(2, "Top", POSITION.WINDOW_TOP, 0, consts.GetClientHeight() - POSITION.WINDOW_HEIGHT, "The top most position of the entire panel."),
      WINDOW_WIDTH = config_window.CreateNumberOption(3, "Width", POSITION.WINDOW_WIDTH, 10, consts.GetClientWidth(), "The width of the entire panel."),
      WINDOW_LINES = config_window.CreateNumberOption(4, "Visible Lines", CONFIG.WINDOW_LINES, 1, 50, "The number of lines visible, will adjust the height based on this."), 
      ANCHOR = config_window.CreateListOption(5, "Preset", "Select...", ANCHOR_LIST, "Anchor the window based on a set of preset rules. Can change all position values."),
    }
  }
 
  return config_window.Show(config, onConfigureDone)
end

onConfigureDone = function(group_id, option_id, config)
  if group_id == "Position" and option_id ~= "WINDOW_LINES" then
    if option_id == "ANCHOR" then
      adjustAnchor(config.raw_value)
    else
      POSITION[option_id] = config.raw_value
    end
  else
    CONFIG[option_id] = config.raw_value
  end

  save()
  create()
  draw()
end

adjustAnchor = function(anchor_id)
  local anchor = ANCHOR_LIST[anchor_id]
  if anchor == nil or anchor == "" then
    return
  end

  local min_height = HEADER_HEIGHT + consts.GetBorderWidth() * 3 + LINE_HEIGHT

  if anchor == "Top Left (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_TOP = 0
  elseif anchor == "Bottom Left (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_TOP = consts.GetClientHeight() - POSITION.WINDOW_HEIGHT
  elseif anchor == "Top Right (Window)" then
    POSITION.WINDOW_LEFT = consts.GetClientWidth() - POSITION.WINDOW_WIDTH
    POSITION.WINDOW_TOP = 0    
  elseif anchor == "Bottom Right (Window)" then
    POSITION.WINDOW_LEFT = consts.GetClientWidth() - POSITION.WINDOW_WIDTH
    POSITION.WINDOW_TOP = consts.GetClientHeight() - POSITION.WINDOW_HEIGHT
  elseif anchor == "Top Fit Width (Output)" then
    if consts.GetOutputTopOutside() < min_height then
      Note("There isn't enough room above the output to anchor there.")
    else
      CONFIG.WINDOW_LINES = calculateOptimalWindowLines(consts.GetOutputTopOutside())
      POSITION.WINDOW_LEFT = consts.GetOutputLeftOutside()
      POSITION.WINDOW_TOP = 0
      POSITION.WINDOW_WIDTH = consts.GetOutputWidthOutside()
    end
  elseif anchor == "Bottom Fit Width (Output)" then
    if consts.GetOutputBottomOutside() > consts.GetClientHeight() - min_height then
      Note("There isn't enough room below the output to anchor there.")
    else
      CONFIG.WINDOW_LINES = calculateOptimalWindowLines(consts.GetClientHeight() - consts.GetOutputBottomOutside())
      POSITION.WINDOW_LEFT = consts.GetOutputLeftOutside()
      POSITION.WINDOW_TOP = consts.GetOutputBottomOutside()
      POSITION.WINDOW_WIDTH = consts.GetOutputWidthOutside()
    end
  elseif anchor ==  "Right Top (Output)" then
    if consts.GetOutputRightOutside() > consts.GetClientWidth() - 250 then
      Note("There isn't enough room to the right of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = consts.GetOutputRightOutside()
      POSITION.WINDOW_TOP = consts.GetOutputTopOutside()
      POSITION.WINDOW_WIDTH = consts.GetClientWidth() - consts.GetOutputRightOutside()
    end
  elseif anchor ==  "Left Top (Output)" then
    if consts.GetOutputLeftOutside() < 250 then
      Note("There isn't enough room to the left of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = 0
      POSITION.WINDOW_TOP = consts.GetOutputTopOutside()
      POSITION.WINDOW_WIDTH = consts.GetOutputLeftOutside()
    end
  elseif anchor ==  "Right Bottom (Output)" then
    if consts.GetOutputRightOutside() > consts.GetClientWidth() - 250 then
      Note("There isn't enough room to the right of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = consts.GetOutputRightOutside()
      POSITION.WINDOW_TOP = consts.GetOutputBottomOutside() - POSITION.WINDOW_HEIGHT
      POSITION.WINDOW_WIDTH = consts.GetClientWidth() - consts.GetOutputRightOutside()
    end
  elseif anchor ==  "Left Bottom (Output)" then
    if consts.GetOutputLeftOutside() < 250 then
      Note("There isn't enough room to the left of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = 0
      POSITION.WINDOW_TOP = consts.GetOutputBottomOutside() - POSITION.WINDOW_HEIGHT
      POSITION.WINDOW_WIDTH = consts.GetOutputLeftOutside()
    end
  end

  create()
end

renderRectangle = function(size_const, border, border_color)
  border = border or 0
  border_color = border_color or CONFIG.BORDER_COLOR

  WindowRectOp(WIN, miniwin.rect_fill, size_const.LEFT, size_const.TOP, size_const.RIGHT, size_const.BOTTOM, size_const.COLOR)
  
  for i = 0, border - 1 do
    WindowRectOp(WIN, miniwin.rect_frame, size_const.LEFT + i, size_const.TOP + i, size_const.RIGHT - i, size_const.BOTTOM - i, border_color)
  end  
end

calculateOptimalWindowLines = function(max_height)
  local height, lines = LINE_HEIGHT, 1
  while height < max_height do
    lines = lines + 1
    height = consts.GetBorderWidth() * 3 + HEADER_HEIGHT + lines * LINE_HEIGHT
  end
  return lines - 1
end

doDebug = function()
  addStyledLine("clan", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "[CLAN] ClanMember: Wow, cool capture plugin!", textcolour = ColourNameToRGB("yellow"), backcolour = ColourNameToRGB("black") }})
  addStyledLine("alliance", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "[ALLIED 1] AllianceMember: Tabs? I've always wanted tabs.", textcolour = ColourNameToRGB("gold"), backcolour = ColourNameToRGB("black") }})
  addStyledLine("tell", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "Someguy tell you 'Can I get that plugin?'", textcolour = ColourNameToRGB("red"), backcolour = ColourNameToRGB("black") }})
  addStyledLine("form", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "You tell the formation 'You guys, using this capture plugins?", textcolour = ColourNameToRGB("cyan"), backcolour = ColourNameToRGB("black") }})
  addStyledLine("announce", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "YO THIS PLUGIN IS NEAT AND STUFF.", textcolour = ColourNameToRGB("white"), backcolour = ColourNameToRGB("black") }})
  addStyledLine("betters", { { text = "[".. getDateString() .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "You have become more learned at 'Offset' (" .. (SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0) .. "%).", textcolour = ColourNameToRGB("white"), backcolour = ColourNameToRGB("black") }})
end

return {
  Prepare = prepare,
  Initialize = initialize, 
  Capture = capture, 
  GetDateString = getDateString, 
  Close = close, 
  IsAutoUpdateEnabled = isAutoUpdateEnabled, 
  OnConfigureDone = onConfigureDone,
  DoDebug = doDebug
}