require "tableshelper"

local config_window = require "configuration_miniwindow"

local WIN = GetPluginID()
local FONT = WIN .. "_capture_font"
local HEADERFONT = WIN .. "_header_font"

local CONFIG = nil

local LINE_HEIGHT = nil
local WINDOW_LINES = 0
local HEADER_HEIGHT = 0
local LAST_REFRESH = 0

local CHARACTER_NAME = ""
local ALL_TABS = { }
local CURRENT_TAB_NAME = "Captures"
local TEXT_BUFFERS = { all = {} }
local FORMATTED_LINES = { all = {} }
local SCROLL_OFFSETS = { all = 0 }
local UNREAD_COUNT = { all = 0 }
local SELECTIONS = { all = { start_x = nil, start_y = nil, end_x = nil, end_y = nil } }

local SCROLLBAR_THUMB_POS
local SCROLLBAR_THUMB_SIZE
local SCROLLBAR_STEPS

local DRAG_SCROLLING = false
local IS_SELECTING = false
local CHARACTER_WIDTH = 0
local LAST_SELECTION = nil
local SELECTED_TEXT = ""
local IS_RESIZING = false
local IS_DRAGGING = false
local DRAG_X = nil
local DRAG_Y = nil

local POSITION = {
  WINDOW_LEFT = nil,
  WINDOW_TOP = nil,
  WINDOW_WIDTH = nil,
  WINDOW_HEIGHT = nil
}

local INIT = false

local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Fit Width (Output)", "6: Bottom Fit Width (Output)", "7: Right Top (Output)", "8: Left Top (Output)",
  "7: Right Bottom (Output)", "8: Left Bottom (Output)"
}

local STRETCH_LIST = {
  "0: None", "1: Horizontal (Window)", "2: Vertical (Window)", "3: Horizontal (Output)", "4: Vertical (Output)"
}

local POSSIBLE_CHANNELS = {
  "affects", "alliance", "announce", "archon", "auction", "aucverb", "clan", "form",
  "notify", "novice", "page", "relay", "say", "shout", "talk", "tell", "yell"
}

local refresh_type = {
  NONE = 1,
  NOTIFICATIONS = 2,
  ALL = 3,
}

function PrepareMiniWindow()
  local serialized_config = GetVariable("last_capture_config")
  if serialized_config ~= nil then
    local temp_config = Deserialize(serialized_config)
    WindowCreate(WIN, temp_config.left, temp_config.top, temp_config.width, temp_config.height, 12, 2, 0)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, temp_config.width, temp_config.height, 0)
    WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, temp_config.border)
    WindowShow(WIN, true)
  end
end

function InitializeMiniWindow(character_name)
  CHARACTER_NAME = character_name

  loadSavedData()
  createWindowAndFont()
  INIT = true
  drawMiniWindow()
end

function AddStyledLine(channel, styledLineSegments)
  local currentOffset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local formattedLines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local was_at_bottom = #formattedLines <= currentOffset + WINDOW_LINES + 1
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
      OnScrollToBottom()
    else
      drawMiniWindow()
    end
  elseif refresh == refresh_type.NOTIFICATIONS then
    drawNotifications()
  end
end

function loadSavedData()
  loadSavedConfig()
  loadSavedTabs()
  loadSavedPosition()
end

function loadSavedConfig()
  local serialized_config = GetVariable(CHARACTER_NAME .. "_capture_config") or ""
  if serialized_config == "" then
    serialized_config = GetVariable("capture_config") or ""
    if serialized_config == "" then
        CONFIG = {}
    else
        CONFIG = Deserialize(serialized_config)
    end
  else
    CONFIG = Deserialize(serialized_config)
  end

  CONFIG.CAPTURE_FONT = getValueOrDefault(CONFIG.CAPTURE_FONT, { name = "Lucida Console", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.HEADER_FONT = getValueOrDefault(CONFIG.HEADER_FONT, { name = "Lucida Console", size = 9, colour = 0, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.LOCK_POSITION = getValueOrDefault(CONFIG.LOCK_POSITION, false)
  CONFIG.SCROLL_WIDTH = getValueOrDefault(CONFIG.SCROLL_WIDTH, 15)
  CONFIG.MAX_LINES = getValueOrDefault(CONFIG.MAX_LINES, 1000)
  CONFIG.NOTIFICATION_COLOR = getValueOrDefault(CONFIG.NOTIFICATION_COLOR, ColourNameToRGB("red"))
  CONFIG.BORDER_COLOR = getValueOrDefault(CONFIG.BORDER_COLOR, ColourNameToRGB("silver"))
  CONFIG.ACTIVE_COLOR = getValueOrDefault(CONFIG.ACTIVE_COLOR, ColourNameToRGB("darkgreen"))
  CONFIG.INACTIVE_COLOR = getValueOrDefault(CONFIG.INACTIVE_COLOR, ColourNameToRGB("grey"))
  CONFIG.DETAIL_COLOR = getValueOrDefault(CONFIG.DETAIL_COLOR, ColourNameToRGB("gray"))
  CONFIG.ACCENT_COLOR = getValueOrDefault(CONFIG.ACCENT_COLOR, ColourNameToRGB("silver"))
  CONFIG.ARROW_COLOR = getValueOrDefault(CONFIG.ARROW_COLOR, ColourNameToRGB("silver"))
  CONFIG.SCROLL_COLOR = getValueOrDefault(CONFIG.SCROLL_COLOR, ColourNameToRGB("darkgray"))
end

function loadSavedTabs()
  local all_tabs_text = GetVariable(CHARACTER_NAME .. "_all_tabs") or ""
  if (all_tabs_text == "") then
    all_tabs_text = GetVariable("all_tabs") or ""
    if (all_tabs_text == "") then
      ALL_TABS = {}
      local default_channels = { 
        alliance = true, announce = true, archon = true, clan = true, form = true, notify = true, affects = true,
        novice = true, page = true, relay = true, shout = true, talk = true, tell = true, yell = true
      }

      ALL_TABS[1] = { 
        name = "Captures", 
        channels = default_channels,
        notify = true
      }
    else
      ALL_TABS = Deserialize(all_tabs_text)
    end
  else
    ALL_TABS = Deserialize(all_tabs_text)
  end

  CURRENT_TAB_NAME = ALL_TABS[1]["name"] or ""
end

function loadSavedPosition()
  local serialized_position = GetVariable(CHARACTER_NAME .. "_capture_position") or ""
  if serialized_position == "" then
    serialized_position = GetVariable("capture_position") or ""
    if serialized_position == "" then
      POSITION = {
        WINDOW_LEFT = GetInfo(274) + GetInfo(276) + GetInfo(277),
        WINDOW_TOP = GetInfo(275) + GetInfo(276) + GetInfo(277) - 250,
        WINDOW_WIDTH = 500,
        WINDOW_HEIGHT = 250
      }
    else
      POSITION = Deserialize(serialized_position)
    end
  else
    POSITION = Deserialize(serialized_position)
  end

  POSITION.WINDOW_HEIGHT = math.min(POSITION.WINDOW_HEIGHT, GetInfo(280))
  POSITION.WINDOW_WIDTH = math.min(POSITION.WINDOW_WIDTH, GetInfo(281))
end

function createWindowAndFont()
  local capfont = CONFIG["CAPTURE_FONT"]
  local hdrfont = CONFIG["HEADER_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, FONT, capfont.name, capfont.size, 
    convertToBool(capfont.bold), 
    convertToBool(capfont.italic), 
    convertToBool(capfont.italic), 
    convertToBool(capfont.strikeout))

  WindowFont(WIN, HEADERFONT, hdrfont.name, hdrfont.size, 
    convertToBool(hdrfont.bold), 
    convertToBool(hdrfont.italic), 
    convertToBool(hdrfont.italic), 
    convertToBool(hdrfont.strikeout))

  CHARACTER_WIDTH = WindowTextWidth(WIN, FONT, "X")
  LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1)
  HEADER_HEIGHT = WindowFontInfo(WIN, HEADERFONT, 1) + 10
  WINDOW_LINES = math.ceil((POSITION.WINDOW_HEIGHT - HEADER_HEIGHT - 7) / LINE_HEIGHT)
end

function drawMiniWindow()
  --if not INIT then return end
    
  WindowShow(WIN, false)

  drawWindow()
  drawTabs()
  drawLines()
  drawScrollbar()
  drawResizeHandle()
  drawScrollToBottom()

  WindowShow(WIN, true)
end

function addLineToTab(tab, channel, styledLineSegments)
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

function addTextToBuffer(name, segments)
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

function formatLines(list)
  if TEXT_BUFFERS[list] == nil then return end

  local maxWidth = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH - 10

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

function drawWindow()
  WindowPosition(WIN, POSITION.WINDOW_LEFT, POSITION.WINDOW_TOP, 4, 2)
  WindowResize(WIN, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, ColourNameToRGB("black"))
  WindowSetZOrder(WIN, 999)

  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_frame, 0, 0, 0, 0, CONFIG.BORDER_COLOR)

  WindowDeleteAllHotspots(WIN)

  WindowAddHotspot(WIN, "textarea", 0, HEADER_HEIGHT + 2, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_HEIGHT - 2, "", "", "OnTextAreaMouseDown", "", "OnTextAreaMouseUp", "", miniwin.cursor_ibeam, 0)  
  WindowDragHandler(WIN, "textarea", "OnTextAreaMouseMove", "", 0x10)
  WindowScrollwheelHandler(WIN, "textarea", "OnWheel")  
end

function drawTabs()
  local x = 1
  for idx, tab in ipairs(ALL_TABS) do
    local tab_name = tab["name"] or ""
    if tab_name ~= "" then
      local text_width = WindowTextWidth(WIN, HEADERFONT, tab_name)
      local tab_color = (tab_name == CURRENT_TAB_NAME) and CONFIG.ACTIVE_COLOR or CONFIG.INACTIVE_COLOR
      local center_pos_x = x + ((text_width + 20) / 2) - (text_width / 2)
      local center_pos_y = (HEADER_HEIGHT - WindowFontInfo(WIN, HEADERFONT, 1)) / 2 + 2
      local tab_tooltip = ""

      WindowRectOp(WIN, miniwin.rect_fill, x, 1, x + text_width + 20, HEADER_HEIGHT, tab_color)
      WindowRectOp(WIN, miniwin.rect_frame, x, 1, x + text_width + 20, HEADER_HEIGHT, CONFIG.BORDER_COLOR)
      WindowText(WIN, HEADERFONT, tab_name, center_pos_x, center_pos_y, 0, 0, CONFIG.HEADER_FONT.colour)

      if tab["notify"] then
        drawNotification(tab_name, x + text_width)
      end

      WindowLine(WIN, 0, HEADER_HEIGHT, POSITION.WINDOW_WIDTH, HEADER_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, 3)
      
      WindowAddHotspot(WIN, tab_name, x, 0, x + text_width + 20, HEADER_HEIGHT, "", "", "", "", "OnHeaderClick", tab_tooltip, miniwin.cursor_hand, 0)

      x = x + text_width + 25
    end
  end

  if not CONFIG.LOCK_POSITION then
    drawDragHandle()
  end
end

function drawNotifications()
  local x = 1
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

function drawNotification(tab_name, x)
  local cnt = UNREAD_COUNT[tab_name] or 0
  if cnt > 0 then
    WindowCircleOp(WIN, miniwin.circle_ellipse, x + 12, HEADER_HEIGHT / 2 - 3, x + 16, HEADER_HEIGHT / 2 - 3 + 4, 
      CONFIG.NOTIFICATION_COLOR, miniwin.pen_solid, 1, CONFIG.NOTIFICATION_COLOR, miniwin.brush_solid)
    WindowHotspotTooltip(WIN, tab_name, cnt .. " unread")
  end  
end

function drawLines()
  WindowRectOp(WIN, miniwin.rect_fill, 1, HEADER_HEIGHT + 1, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH - 1, POSITION.WINDOW_HEIGHT - 1, ColourNameToRGB("black"))
  
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local y = HEADER_HEIGHT + 2

  SELECTED_TEXT = ""

  for i = offset + 1, #lines do
    if y + LINE_HEIGHT > POSITION.WINDOW_HEIGHT then
      break
    end

    local segments = lines[i]
    local x = 5
    for _, s in ipairs(segments) do
      local w = WindowTextWidth(WIN, FONT, s.text)

      drawSelection(x, y, w, offset, s)

      WindowText(WIN, FONT, s.text, x, y, 0, 0, s.textcolour)
      x = x + w
    end
    y = y + LINE_HEIGHT
  end
end

function drawSelection(x, y, w, offset, s)
  local selection = SELECTIONS[CURRENT_TAB_NAME]
  if not hasSelection(selection) then return end

  --local low_y = math.min(selection.start_y, selection.end_y)
  --local high_y = math.max(selection.start_y, selection.end_y)  
  --local starting_line = clamp(math.floor((low_y - HEADER_HEIGHT + 2) / LINE_HEIGHT) + offset + 1, 1, #FORMATTED_LINES[CURRENT_TAB_NAME])
  --local ending_line = clamp(math.floor((high_y - HEADER_HEIGHT + 2) / LINE_HEIGHT) + offset + 1, starting_line, #FORMATTED_LINES[CURRENT_TAB_NAME])
  local drawing_line = math.floor((y - HEADER_HEIGHT + 2) / LINE_HEIGHT) + offset + 1

  WindowRectOp(WIN, miniwin.rect_fill, x, y, x + w, y + LINE_HEIGHT, ColourNameToRGB(s.backcolour or "black"))

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

function hasSelection(s)
  return s ~= nil and s.start_x ~= nil and s.start_y ~= nil and s.end_x ~= nil and s.end_y ~= nil 
    and (s.start_x - s.end_x >= CHARACTER_WIDTH or s.end_x - s.start_x >= CHARACTER_WIDTH or s.start_y - s.end_y >= CHARACTER_WIDTH or s.end_y - s.start_y >= CHARACTER_WIDTH)
end

function drawScrollbar()
  local adjusted_height_top = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH
  local adjusted_height_bottom = POSITION.WINDOW_HEIGHT
  if not CONFIG.LOCK_POSITION then
    adjusted_height_top = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH * 2
    adjusted_height_bottom = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH
  end

  WindowRectOp(WIN, miniwin.rect_fill, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, HEADER_HEIGHT + CONFIG.SCROLL_WIDTH, POSITION.WINDOW_WIDTH,
    adjusted_height_top, CONFIG.DETAIL_COLOR)
  WindowRectOp(WIN, miniwin.rect_fill, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH + 5, HEADER_HEIGHT + CONFIG.SCROLL_WIDTH + 5, POSITION.WINDOW_WIDTH - 5,
    adjusted_height_top - 5, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_frame, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH + 1, HEADER_HEIGHT + 1, POSITION.WINDOW_WIDTH,
    POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH, CONFIG.DETAIL_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, HEADER_HEIGHT, POSITION.WINDOW_WIDTH,
    HEADER_HEIGHT + CONFIG.SCROLL_WIDTH, CONFIG.DETAIL_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, adjusted_height_top,
    POSITION.WINDOW_WIDTH, adjusted_height_bottom, CONFIG.DETAIL_COLOR)  

  local formattedLines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local TOTAL_LINES = #formattedLines
  local OFFSET = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0

  local scrollbar_height = POSITION.WINDOW_HEIGHT - (3 * CONFIG.SCROLL_WIDTH) - HEADER_HEIGHT
  if CONFIG.LOCK_POSITION then
    scrollbar_height = POSITION.WINDOW_HEIGHT - (2 * CONFIG.SCROLL_WIDTH) - HEADER_HEIGHT
  end
  SCROLLBAR_THUMB_SIZE = math.min(scrollbar_height, math.max(10, scrollbar_height * (WINDOW_LINES / (TOTAL_LINES))))
  local maxScroll = TOTAL_LINES - WINDOW_LINES

  if maxScroll <= 0 then
    SCROLLBAR_THUMB_SIZE = scrollbar_height
  end

  local scrollRatio = OFFSET / math.max(maxScroll, 1)
  local SCROLLBAR_THUMB_POS = (scrollRatio * (scrollbar_height - SCROLLBAR_THUMB_SIZE)) + HEADER_HEIGHT + CONFIG.SCROLL_WIDTH
  
  drawScrollbarDetails()

  WindowRectOp(WIN, miniwin.rect_fill, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH + 1, SCROLLBAR_THUMB_POS, POSITION.WINDOW_WIDTH - 1,
    SCROLLBAR_THUMB_POS + SCROLLBAR_THUMB_SIZE, CONFIG.SCROLL_COLOR)
  WindowRectOp(WIN, miniwin.rect_frame, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH + 1, SCROLLBAR_THUMB_POS, POSITION.WINDOW_WIDTH - 1,
    SCROLLBAR_THUMB_POS + SCROLLBAR_THUMB_SIZE, ColourNameToRGB("black"))

  if not DRAG_SCROLLING then
    WindowAddHotspot(WIN, "up", POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, HEADER_HEIGHT, 0, HEADER_HEIGHT + CONFIG.SCROLL_WIDTH, "", "", "ScrollArrowsMouseDown", "", "", "", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, "down", POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_HEIGHT - (2 * CONFIG.SCROLL_WIDTH), 0, POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH, "", "", "ScrollArrowsMouseDown", "", "", "",  miniwin.cursor_hand, 0)

    WindowAddHotspot(WIN, "scroll_thumb", POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, SCROLLBAR_THUMB_POS, POSITION.WINDOW_WIDTH, SCROLLBAR_THUMB_POS + SCROLLBAR_THUMB_SIZE, 
      "", "", "OnScrollThumbDragStart", "", "", "", miniwin.cursor_hand, 0)
    WindowDragHandler(WIN, "scroll_thumb", "OnScrollThumbDragMove", "OnScrollThumbDragRelease", 0)
  end
end

local START_DRAG_Y, START_DRAG_OFFSET = 0, 0

function OnScrollThumbDragStart()
  DRAG_SCROLLING = true
  START_DRAG_Y = WindowInfo(WIN, 18)
  START_DRAG_OFFSET = SCROLL_OFFSETS[CURRENT_TAB_NAME]
end

function OnScrollThumbDragMove()
  if DRAG_SCROLLING then
    local mouse_pos_y = WindowInfo(WIN, 18)
    local total_lines = #FORMATTED_LINES[CURRENT_TAB_NAME]
    local scrollable_lines = math.max(total_lines - WINDOW_LINES, 0)
    local delta = mouse_pos_y - START_DRAG_Y
    local scrollbar_height = POSITION.WINDOW_HEIGHT - (3 * CONFIG.SCROLL_WIDTH) - HEADER_HEIGHT
    if CONFIG.LOCK_POSITION then scrollbar_height = POSITION.WINDOW_HEIGHT - (2 * CONFIG.SCROLL_WIDTH) - HEADER_HEIGHT end
    local pixels_per_line = scrollbar_height / total_lines
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

function drawScrollbarDetails()
  local leftScroll = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH

  local upArrow = string.format("%i,%i,%i,%i,%i,%i", 
    leftScroll + (CONFIG.SCROLL_WIDTH / 3), HEADER_HEIGHT + (CONFIG.SCROLL_WIDTH * 2 / 3),
    leftScroll + (CONFIG.SCROLL_WIDTH / 2), HEADER_HEIGHT + (CONFIG.SCROLL_WIDTH / 3), 
    leftScroll + (CONFIG.SCROLL_WIDTH * 2 / 3), HEADER_HEIGHT + (CONFIG.SCROLL_WIDTH * 2 / 3))

  WindowPolygon(WIN, upArrow, CONFIG.ARROW_COLOR, miniwin.pen_solid, 1, CONFIG.ARROW_COLOR, miniwin.brush_solid, true,
    false)

  local adjusted_height = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH
  if CONFIG.LOCK_POSITION then
    adjusted_height = POSITION.WINDOW_HEIGHT
  end
  local downArrow = string.format("%i,%i,%i,%i,%i,%i", 
    leftScroll + (CONFIG.SCROLL_WIDTH / 3), adjusted_height - (CONFIG.SCROLL_WIDTH * 2 / 3), 
    leftScroll + (CONFIG.SCROLL_WIDTH / 2), adjusted_height - (CONFIG.SCROLL_WIDTH / 3),
    leftScroll + (CONFIG.SCROLL_WIDTH * 2 / 3), adjusted_height - (CONFIG.SCROLL_WIDTH * 2 / 3))

  WindowPolygon(WIN, downArrow, CONFIG.ARROW_COLOR, miniwin.pen_solid, 1, CONFIG.ARROW_COLOR, miniwin.brush_solid, true,
    false)
end

function drawDragHandle()
  local left = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH
  local top = 1
  local right = left + CONFIG.SCROLL_WIDTH
  local bottom = top + HEADER_HEIGHT - 1

  WindowRectOp(WIN, miniwin.rect_fill, left, top, right, bottom, CONFIG.DETAIL_COLOR)
  WindowLine(WIN, left + 3, top + 8, right - 3, top + 8, CONFIG.ACCENT_COLOR, miniwin.pen_solid, 1)
  WindowLine(WIN, left + 3, top + 12, right - 3, top + 12, CONFIG.ACCENT_COLOR, miniwin.pen_solid, 1)
  WindowLine(WIN, left + 3, top + 16, right - 3, top + 16, CONFIG.ACCENT_COLOR, miniwin.pen_solid, 1)

  WindowAddHotspot(WIN, "drag_" .. WIN, POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, 0, POSITION.WINDOW_WIDTH, HEADER_HEIGHT, "", "", "drag_mousedown", "", "", "", 10, 0)
  WindowDragHandler (WIN, "drag_" .. WIN, "drag_move", "drag_release", 0)
end

function drag_mousedown(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    IS_DRAGGING = true
    DRAG_X = WindowInfo(WIN, 14)
    DRAG_Y = WindowInfo(WIN, 15)
  elseif flags == miniwin.hotspot_got_rh_mouse then
    showUnlockedRightClick()
  end
end

function drag_move(flags, hotspot_id)
  if IS_DRAGGING then
    local pos_x = clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - POSITION.WINDOW_WIDTH)
    local pos_y = clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

    SetCursor(miniwin.cursor_hand)
    WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
  end
end

function drag_release(flags, hotspot_id)
  if IS_DRAGGING then
    IS_DRAGGING = false
    POSITION.WINDOW_LEFT = WindowInfo(WIN, 10)
    POSITION.WINDOW_TOP = WindowInfo(WIN, 11)
    saveMiniWindow()
    Repaint()
  end
end

function clamp(val, min, max)
  val = val or 0
  min = min or 0
  max = max or 0
  return math.max(min, math.min(val, max))
end

function drawResizeHandle()
  if CONFIG.LOCK_POSITION then return end
    
  local left = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH
  local top = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH
  local right = left + CONFIG.SCROLL_WIDTH
  local bottom = top + CONFIG.SCROLL_WIDTH

  WindowRectOp(WIN, miniwin.rect_fill, left, top, right, bottom, CONFIG.DETAIL_COLOR)

  local m = 2
  local n = 2

  while (left + m + 2 <= right - 3 and top + n + 1 <= bottom - 4) do
    WindowLine(WIN, left + m + 1, bottom - 4, right - 3, top + n, CONFIG.ACCENT_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, left + m + 2, bottom - 4, right - 3, top + n + 1, CONFIG.ACCENT_COLOR, miniwin.pen_solid, 1)
    m = m + 3
    n = n + 3
  end

  WindowAddHotspot(WIN, "resizer", POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH, POSITION.WINDOW_WIDTH, POSITION.WINDOW_HEIGHT, "", "", "OnResizerDown", "", "", "", miniwin.cursor_nw_se_arrow, 0)
  WindowDragHandler(WIN, "resizer", "OnResizerDrag", "OnResizerRelease", 0)
end

function drawScrollToBottom()
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0

  if offset + WINDOW_LINES < #lines then
    local left = POSITION.WINDOW_WIDTH - CONFIG.SCROLL_WIDTH * 4
    local top = POSITION.WINDOW_HEIGHT - CONFIG.SCROLL_WIDTH * 3
    local right = left + CONFIG.SCROLL_WIDTH * 2
    local bottom = top + CONFIG.SCROLL_WIDTH * 2

    WindowRectOp(WIN, miniwin.rect_fill, left, top, right, bottom, CONFIG.DETAIL_COLOR)
    
    local centerX = (left + right) / 2
    local point1 = { x = centerX, y = bottom - 10 }
    local point2 = { x = left + 10, y = top + 10 }
    local point3 = { x = right - 10, y = top + 10 }

    local downArrow = string.format("%d,%d,%d,%d,%d,%d", point1.x, point1.y, point2.x, point2.y, point3.x, point3.y)

    WindowPolygon(WIN, downArrow, CONFIG.SCROLL_COLOR, miniwin.pen_solid, 1, CONFIG.ACCENT_COLOR, miniwin.brush_solid, true, false)

    WindowAddHotspot(WIN, "scroll_to_bottom", left, top, right, bottom, "", "", "OnScrollToBottom", "", "", "Scroll to bottom", miniwin.cursor_hand, 0)
  end
end

function OnScrollToBottom()
  local list = CURRENT_TAB_NAME
  local formattedLines = FORMATTED_LINES[list] or {}
  SCROLL_OFFSETS[list] = math.max(0, #formattedLines - WINDOW_LINES)
  drawMiniWindow()
end

-- Scroll handler
function OnWheel(flags, hotspot_id)
  if bit.band(flags, miniwin.wheel_scroll_back) ~= 0 then
    moveScrollBar("down")
  else
    moveScrollBar("up")
  end
end

function moveScrollBar(direction)
  local offset = SCROLL_OFFSETS[CURRENT_TAB_NAME] or 0
  local lines = FORMATTED_LINES[CURRENT_TAB_NAME] or {}
  
  if direction == "down" then
    offset = math.min(offset + 1, math.max(0, #lines - WINDOW_LINES))
  else
    offset = math.max(0, offset - 1)
  end

  SCROLL_OFFSETS[CURRENT_TAB_NAME] = offset
  drawMiniWindow()
end

function OnHeaderClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if CURRENT_TAB_NAME ~= hotspot_id then
      formatLines(hotspot_id)
    end
    CURRENT_TAB_NAME = hotspot_id
    OnScrollToBottom()
    UNREAD_COUNT[hotspot_id] = 0
    drawMiniWindow()
  else
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
    saveMiniWindow()
    createWindowAndFont()
    drawMiniWindow()
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
    
    drawMiniWindow()
  end
end

function doRightClickMenu()
  local menu_items = "copy|clear|clear all|-|configure"

  local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
  if result == "copy" then
    copySelectedText()
  elseif result == "clear" then
    FORMATTED_LINES[CURRENT_TAB_NAME] = {}
    TEXT_BUFFERS[CURRENT_TAB_NAME] = {}
    SCROLL_OFFSETS[CURRENT_TAB_NAME] = 0
    drawMiniWindow()
  elseif result == "clear all" then
    for x, y in pairs(FORMATTED_LINES) do
      FORMATTED_LINES[x] = {}
      TEXT_BUFFERS[x] = {}
      SCROLL_OFFSETS[x] = 0
      UNREAD_COUNT = { }
      drawMiniWindow()
    end
  elseif result == "configure" then
    configure()
  end
end

function doRightClickHeaderMenu(name)
  local menu_items = ">channels | "
  
  for i = 1, #ALL_TABS do
    local tab = ALL_TABS[i]
    if tab["name"] == name then
      for idx, value in ipairs(POSSIBLE_CHANNELS) do
        if tab["channels"][value] then
          menu_items = menu_items .. "+" .. value .. " | "
        else
          menu_items = menu_items .. value .. " | "
        end
      end

      menu_items = menu_items .. "< | - | clear | mark as read | - | rename tab | add new tab"

      if i > 1 then
        menu_items = menu_items .. " | delete tab"
      end

      if tab["notify"] then
        menu_items = menu_items .. " | +notify"
      else
        menu_items = menu_items .. " | notify"
      end

      menu_items = menu_items .. "| - | configure"

      local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)

      if result == "clear" then
        clearTab(name)
      elseif result == "mark as read" then
        UNREAD_COUNT[name] = 0
        drawMiniWindow()

      elseif result == "rename tab" then
        local new_name = utils.inputbox(tab["name"] or "", "Rename Tab", name)
        if new_name ~= nil and #new_name > 0 then 
          ALL_TABS[i]["name"] = new_name
          drawMiniWindow()
        end

      elseif result == "add new tab" then
        OnNewTabClick()
      
      elseif result == "delete tab" then
        if i > 1 then
          table.remove(ALL_TABS, i)
          drawMiniWindow()
        else
          Note("You can't remove the first tab!")
        end

      elseif result == "notify" then
        if ALL_TABS[i]["notify"] then
          ALL_TABS[i]["notify"] = nil
        else
          ALL_TABS[i]["notify"] = true
        end
      
      elseif result == "configure" then
        configure()
        
      elseif result ~= "" then
        if getTableIndex(POSSIBLE_CHANNELS, result) ~= nil then
          if tab["channels"][result] then
            ALL_TABS[i]["channels"][result] = nil
          else
            ALL_TABS[i]["channels"][result] = true
          end

          drawMiniWindow()
        end
      end

      saveMiniWindow()

      break;
    end
  end 
end

function showUnlockedRightClick()
  local menu_items =  "Lock Position | >Anchor | "
  for _, a in ipairs(ANCHOR_LIST) do
    menu_items = menu_items .. a .. " | "
  end
  menu_items = menu_items .. " < | >Stretch | "
  for _, s in ipairs(STRETCH_LIST) do
    menu_items = menu_items .. s .. " | "
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
    for i, a in ipairs(STRETCH_LIST) do
      if result == a then
        adjustStretch(i)
      end
    end
  end
  saveMiniWindow()
  drawMiniWindow()
end

function copySelectedText()
  SetClipboard(SELECTED_TEXT)
  Note("Copied '" .. SELECTED_TEXT .. "' to the clipboard")
end

function getSubstringByPixelRange(text, startWidth, endWidth)
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

function saveMiniWindow()
  local sticky_options = { 
    left = WindowInfo(WIN, 10), top = WindowInfo(WIN, 11), 
    width = WindowInfo(WIN, 3), height = WindowInfo(WIN, 4), 
    border = CONFIG.BORDER_COLOR,
  }

  SetVariable("last_capture_config", Serialize(sticky_options))
  SetVariable(CHARACTER_NAME .. "_all_tabs", Serialize(ALL_TABS))
  SetVariable(CHARACTER_NAME .. "_capture_position", Serialize(POSITION))
  SetVariable(CHARACTER_NAME .. "_capture_config", Serialize(CONFIG))
  SaveState()
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

function OnTextAreaMouseMove(flags, hotspot_id)
  if IS_SELECTING then
    local end_x = roundToNearestCharacter(WindowInfo(WIN, 14)) + 5
    local end_y = WindowInfo(WIN, 15)

    SELECTIONS[CURRENT_TAB_NAME].end_x = end_x
    SELECTIONS[CURRENT_TAB_NAME].end_y = end_y

    local selection = SELECTIONS[CURRENT_TAB_NAME]

    SELECTIONS[CURRENT_TAB_NAME].starting_line = clamp(math.floor((math.min(selection.start_y, selection.end_y) - HEADER_HEIGHT + 2) / LINE_HEIGHT) + SCROLL_OFFSETS[CURRENT_TAB_NAME] + 1, 1, #FORMATTED_LINES[CURRENT_TAB_NAME])
    SELECTIONS[CURRENT_TAB_NAME].ending_line = clamp(math.floor((math.max(selection.start_y, selection.end_y) - HEADER_HEIGHT + 2) / LINE_HEIGHT) + SCROLL_OFFSETS[CURRENT_TAB_NAME] + 1, SELECTIONS[CURRENT_TAB_NAME].starting_line, #FORMATTED_LINES[CURRENT_TAB_NAME])

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
    drawMiniWindow()
  end
end

function OnNewTabClick()
  local new_index = #ALL_TABS + 1
  local channels = {}
  for _, value in ipairs(POSSIBLE_CHANNELS) do
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

    drawMiniWindow()
  end
end

function convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
end

function roundToNearestCharacter(position)
  return position - (position % CHARACTER_WIDTH)
end

function showWindow()
  WindowShow(WIN, true)
end

function hideWindow()
  WindowShow(WIN, false)
end

function configure()
  local config = {
    Capture = {

      CAPTURE_FONT = { type = "font", value = CONFIG.CAPTURE_FONT.name .. " (" .. CONFIG.CAPTURE_FONT.size .. ")", raw_value = CONFIG.CAPTURE_FONT },
      HEADER_FONT = { type = "font", value = CONFIG.HEADER_FONT.name .. " (" .. CONFIG.HEADER_FONT.size .. ")", raw_value = CONFIG.HEADER_FONT },
      LOCK_POSITION = { type = "bool", raw_value = CONFIG.LOCK_POSITION },
      SCROLL_WIDTH = { label = "Scrollbar Width", type = "number", raw_value = CONFIG.SCROLL_WIDTH, min = 5, max = 50 },
      MAX_LINES = { type = "number", raw_value = CONFIG.MAX_LINES, min = 50, max = 50000 },
      NOTIFICATION_COLOR = { type = "color", raw_value = CONFIG.NOTIFICATION_COLOR },
      BORDER_COLOR = { label = "Border Color", type = "color", value = CONFIG.BORDER_COLOR, raw_value = CONFIG.BORDER_COLOR },
      ACTIVE_COLOR = { label = "Active Tab Color", type = "color", value = CONFIG.ACTIVE_COLOR, raw_value = CONFIG.ACTIVE_COLOR },
      INACTIVE_COLOR = { label = "Inactive Tab Color", type = "color", value = CONFIG.INACTIVE_COLOR, raw_value = CONFIG.INACTIVE_COLOR },
      DETAIL_COLOR = { label = "Detail Color", type = "color", value = CONFIG.DETAIL_COLOR, raw_value = CONFIG.DETAIL_COLOR },
      ACCENT_COLOR = { label = "Accent Color", type = "color", value = CONFIG.ACCENT_COLOR, raw_value = CONFIG.ACCENT_COLOR },
      ARROW_COLOR = { label = "Scroll Arrow Color", type = "color", value = CONFIG.ARROW_COLOR, raw_value = CONFIG.ARROW_COLOR },
      SCROLL_COLOR = { label = "Scroll Handle Color", type = "color", value = CONFIG.SCROLL_COLOR, raw_value = CONFIG.SCROLL_COLOR },
      ANCHOR = { label = "Anchor", type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST },
      STRETCH = { type = "list", value = "None", raw_value = 1, list = STRETCH_LIST }
    },
    Position = {
      WINDOW_LEFT = { type = "number", raw_value = POSITION.WINDOW_LEFT, min = 0, max = GetInfo(281) - 50 },
      WINDOW_TOP = { type = "number", raw_value = POSITION.WINDOW_TOP, min = 0, max = GetInfo(280) - 50 },
      WINDOW_WIDTH = { type = "number", raw_value = POSITION.WINDOW_WIDTH, min = 50, max = GetInfo(281) },
      WINDOW_HEIGHT = { type = "number", raw_value = POSITION.WINDOW_HEIGHT, min = 50, max = GetInfo(280) },
    }
  }
  
  config_window.Show(config, configureDone)
end

function configureDone(group_id, option_id, config)
  if group_id == "Position" then
    POSITION[option_id] = config.raw_value
  else
    if option_id == "ANCHOR" then
      adjustAnchor(config.raw_value)
    elseif option_id == "STRETCH" then
      adjustStretch(config.raw_value)
    else
      CONFIG[option_id] = config.raw_value
    end
  end

  saveMiniWindow()
  createWindowAndFont()
  drawMiniWindow()
end

function adjustAnchor(anchor_id)
  local anchor = ANCHOR_LIST[anchor_id]:sub(4)
  if anchor == nil or anchor == "" or anchor == "None" then
    return
  end

  local output_left = GetInfo(272) - GetInfo(276) - GetInfo(277)
  local output_top = GetInfo(273) - GetInfo(276) - GetInfo(277)
  local output_right = GetInfo(274) + GetInfo(276) + GetInfo(277)
  local output_bottom = GetInfo(275) + GetInfo(276) + GetInfo(277)

  if anchor == "Top Left (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_TOP = 0
  elseif anchor == "Bottom Left (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)
  elseif anchor == "Top Right (Window)" then
    POSITION.WINDOW_LEFT = GetInfo(281) - POSITION.WINDOW_WIDTH
    POSITION.WINDOW_TOP = 0    
  elseif anchor == "Bottom Right (Window)" then
    POSITION.WINDOW_LEFT = GetInfo(281) - POSITION.WINDOW_WIDTH
    POSITION.WINDOW_TOP = GetInfo(280) - WindowInfo(WIN, 4)    
  elseif anchor == "Top Fit Width (Output)" then
    if output_top < 25 then
      Note("There isn't enough room above the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = output_left
      POSITION.WINDOW_TOP = 0
      POSITION.WINDOW_HEIGHT = output_top
      POSITION.WINDOW_WIDTH = output_right - output_left
    end
  elseif anchor == "Bottom Fit Width (Output)" then
    if output_bottom > GetInfo(280) - 25 then
      Note("There isn't enough room below the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = output_left
      POSITION.WINDOW_TOP = output_bottom
      POSITION.WINDOW_HEIGHT = GetInfo(280) - output_bottom
      POSITION.WINDOW_WIDTH = output_right - output_left
    end
  elseif anchor ==  "Right Top (Output)" then
    if output_right > GetInfo(281) - 250 then
      Note("There isn't enough room to the right of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = output_right
      POSITION.WINDOW_TOP = output_top
      POSITION.WINDOW_WIDTH = GetInfo(281) - output_right
    end
  elseif anchor ==  "Left Top (Output)" then
    if output_left < 250 then
      Note("There isn't enough room to the left of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = 0
      POSITION.WINDOW_TOP = output_top
      POSITION.WINDOW_WIDTH = output_left
    end

    elseif anchor ==  "Right Bottom (Output)" then
    if output_right > GetInfo(281) - 250 then
      Note("There isn't enough room to the right of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = output_right
      POSITION.WINDOW_TOP = output_bottom - POSITION.WINDOW_HEIGHT
      POSITION.WINDOW_WIDTH = GetInfo(281) - output_right
    end
  elseif anchor ==  "Left Bottom (Output)" then
    if output_left < 250 then
      Note("There isn't enough room to the left of the output to anchor there.")
    else
      POSITION.WINDOW_LEFT = 0
      POSITION.WINDOW_TOP = output_bottom - POSITION.WINDOW_HEIGHT
      POSITION.WINDOW_WIDTH = output_left
    end
  end

  createWindowAndFont()
end

function adjustStretch(stretch_id)
  local stretch = STRETCH_LIST[stretch_id]:sub(4)
  if stretch == nil or stretch == "" or stretch == "None" then
    return
  end
  
  local output_left = GetInfo(272) - GetInfo(276) - GetInfo(277)
  local output_top = GetInfo(273) - GetInfo(276) - GetInfo(277)
  local output_right = GetInfo(274) + GetInfo(276) + GetInfo(277)
  local output_bottom = GetInfo(275) + GetInfo(276) + GetInfo(277)

  if stretch == "Horizontal (Window)" then 
    POSITION.WINDOW_LEFT = 0
    POSITION.WINDOW_WIDTH = GetInfo(281)
  elseif stretch == "Vertical (Window)" then 
    POSITION.WINDOW_TOP = 0
    POSITION.WINDOW_HEIGHT = GetInfo(280)
  elseif stretch == "Horizontal (Output)" then
    POSITION.WINDOW_LEFT = output_left
    POSITION.WINDOW_WIDTH = output_right - output_left
  elseif stretch == "Veritcal (Output)" then
    POSITION.WINDOW_TOP = output_top
    POSITION.WINDOW_HEIGHT = output_bottom - output_top
  end

  createWindowAndFont()
end

function getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
end

function doDebug()
  --Note(Serialize(CONFIG))
  --Note("LineHeight: " .. LINE_HEIGHT)
  --Note("HeaderHeight: " .. HEADER_HEIGHT)
  --Note("WindowLines: " .. WINDOW_LINES)
  AddStyledLine("clan", { { text = "[".. os.date("%H:%M:%S") .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "[CLAN] ClanMember: Wow, cool capture plugin!", textcolour = ColourNameToRGB("yellow"), backcolour = ColourNameToRGB("black") }})
  AddStyledLine("alliance", { { text = "[".. os.date("%H:%M:%S") .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "[ALLIED 1] AllianceMember: Tabs? I've always wanted tabs.", textcolour = ColourNameToRGB("gold"), backcolour = ColourNameToRGB("black") }})
  AddStyledLine("tell", { { text = "[".. os.date("%H:%M:%S") .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "Someguy tell you 'Can I get that plugin?'", textcolour = ColourNameToRGB("red"), backcolour = ColourNameToRGB("black") }})
  AddStyledLine("form", { { text = "[".. os.date("%H:%M:%S") .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "You tell the formation 'You guys, using this capture plugins?", textcolour = ColourNameToRGB("cyan"), backcolour = ColourNameToRGB("black") }})
  AddStyledLine("announce", { { text = "[".. os.date("%H:%M:%S") .. "] ", textcolour = ColourNameToRGB("silver"), backcolour = ColourNameToRGB("black")}, { text = "YO THIS PLUGIN IS NEAT AND STUFF.", textcolour = ColourNameToRGB("white"), backcolour = ColourNameToRGB("black") }})
end