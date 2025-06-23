local WIN = GetPluginID()
local FONT = nil
local FONT_STRIKE = nil
local FONT_UNDERLINE = nil

local WINDOW_WIDTH = 50
local WINDOW_HEIGHT = 25
local COL_1_WIDTH = 0
local COL_2_WIDTH = 0
local LINE_HEIGHT = nil
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 25
local RIGHT = 1410
local TOP = 250

local TEXT_BUFFER = { }
local FORMATTED_LINES = { }

local EXPANDED = true
local INIT = false

function InitMiniWindow()
  initializeWindowProperties()
  drawMiniWindow()
  INIT = true
end

function initializeWindowProperties()
  if not INIT then
    FONT = "font" .. WIN
    FONT_STRIKE = "font_strike" .. WIN
    FONT_UNDERLINE = "font_underline" .. WIN

    check(WindowCreate(WIN, 0, 0, 1, 1, 0, 0, ColourNameToRGB("black")))
    check(WindowFont(WIN, FONT, "Lucida Console", 9))
    check(WindowFont(WIN, FONT_STRIKE, "Lucida Console", 9, false, false, false, true))
    check(WindowFont(WIN, FONT_UNDERLINE, "Lucida Console", 9, false, false, true))

    LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1) - WindowFontInfo(WIN, FONT, 4) + 2

    WindowCreate(WIN, 0, 0, 0, 0, 4, 2, ColourNameToRGB("black"))
  end
end

function drawMiniWindow()
  findAndSetWindowSize()
  drawQuestPanel()
  WindowShow(WIN, true)
end

function findAndSetWindowSize()
  local final_width = BUTTON_WIDTH
  local final_height = BUTTON_HEIGHT

  if #TEXT_BUFFER == 0 then
    EXPANDED = false
  end

  if EXPANDED then
    final_height = #TEXT_BUFFER * LINE_HEIGHT + BUTTON_HEIGHT + 4

    for _, styles in ipairs(TEXT_BUFFER) do
      local currentWidth = 0

      for _, seg in ipairs(styles) do
        currentWidth = currentWidth + WindowTextWidth(WIN, FONT, seg.text)
      end

      if currentWidth > final_width then
        final_width = currentWidth
      end
    end
  end

  WINDOW_WIDTH = math.max(final_width + 6, BUTTON_WIDTH)
  WINDOW_HEIGHT = math.max(final_height, BUTTON_HEIGHT)

  WindowPosition(WIN, RIGHT - WINDOW_WIDTH, TOP, 4, 2)
  WindowResize(WIN, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  WindowSetZOrder(WIN, 9999)
end

function drawQuestPanel()
  local lines = TEXT_BUFFER or {}

  local button_label = "Quest"
  local button_color = ColourNameToRGB("gray")
  local label_color = ColourNameToRGB("white")
  
  if #lines == 0 then
    button_color = ColourNameToRGB("dimgray")
    label_color = ColourNameToRGB("gray")
    EXPANDED = false
  elseif EXPANDED then 
    button_label = "Hide" 
  end

  local text_width = WindowTextWidth(WIN, FONT, button_label)
  WindowRectOp(WIN, miniwin.rect_fill, WINDOW_WIDTH - BUTTON_WIDTH, 0, WINDOW_WIDTH, BUTTON_HEIGHT, button_color)
  WindowText(WIN, FONT, button_label, WINDOW_WIDTH - (BUTTON_WIDTH / 2) - (text_width / 2), 8, 0, 0, label_color)

  if #lines > 0 then
    WindowAddHotspot(WIN, "quest", WINDOW_WIDTH - BUTTON_WIDTH, 0, WINDOW_WIDTH, BUTTON_HEIGHT, "", "", "", "", "OnQuestHeaderClick", "", miniwin.cursor_hand, 0)
  else
    WindowDeleteHotspot(WIN, "quest")
  end
 
  if not EXPANDED then
    return
  end

  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, WINDOW_WIDTH - BUTTON_WIDTH, BUTTON_HEIGHT, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_fill, 0, BUTTON_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("black"))
  WindowRectOp(WIN, miniwin.rect_frame, 0, BUTTON_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, ColourNameToRGB("silver"))

  local y = BUTTON_HEIGHT + 4
  for i = 1, #lines do
    local x = 4
    if y + LINE_HEIGHT > WINDOW_HEIGHT then
      break
    end

    local lineText = ""
    local segments = lines[i]
    for _, s in ipairs(segments) do
      lineText = lineText .. s.text
      local w = WindowTextWidth(WIN, FONT, s.text)
      if s.textcolour == ColourNameToRGB("dimgray") then
        WindowText(WIN, FONT_STRIKE, s.text, x + 2, y, 0, 0, s.textcolour)
      else
        local room_name = string.match(s.text , "^Journey to%s+(.+)$")
        if room_name then
          WindowText(WIN, FONT_UNDERLINE, s.text, x + 2, y, 0, 0, s.textcolour)
          WindowAddHotspot(WIN, room_name, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "OnPhaseClick", "", miniwin.cursor_hand, 0)
        else
          WindowText(WIN, FONT, s.text, x + 2, y, 0, 0, s.textcolour)
        end
      end      

      x = x + w
    end
    if #lineText > 0 then
      y = y + LINE_HEIGHT
    end
  end
end

function AddLine(segments)
  if not INIT then
    InitMiniWindow()
  end

  EXPANDED = true

  if TEXT_BUFFER == nil then 
    clear()
  end

  table.insert(TEXT_BUFFER, segments)

  drawMiniWindow()
end

function OnPhaseClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    Execute("mapper find " .. hotspot_id)
  end
end

function OnQuestHeaderClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    EXPANDED = not EXPANDED
    findAndSetWindowSize()
    drawMiniWindow()
  end
end

function clear() 
  if INIT then
    TEXT_BUFFER = {}
    FORMATTED_LINES = {}
    EXPANDED = false
    findAndSetWindowSize()
    drawMiniWindow()
  end
end

function showWindow()
  WindowShow(WIN, true)
end

function hideWindow()
  WindowShow(WIN, false)
end