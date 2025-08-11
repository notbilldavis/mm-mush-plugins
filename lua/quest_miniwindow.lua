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

local DRAG_X = nil
local DRAG_Y = nil

local TEXT_BUFFER = { }
local FORMATTED_LINES = { }
local SECTION_STATUS = { }

local CURRENT_INFO = nil
local PURSUER_TARGET = nil
local CRYSTAL_TARGET = nil
local COLLECTED_PART = nil

local EXPANDED = true
local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

local EXPAND_LIST = {
  "0: Never", "1: First Phase", "2: All Phases"
}

function InitializeMiniWindow()
  loadSavedData()
  createWindowAndFont()
  drawMiniWindow()
end

function loadSavedData()
  local serialized_config = GetVariable("quest_config") or ""
  if serialized_config == "" then
    CONFIG = {}
  else
    CONFIG = Deserialize(serialized_config)
  end

  CONFIG.BUTTON_FONT = getValueOrDefault(CONFIG.BUTTON_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.QUEST_FONT = getValueOrDefault(CONFIG.QUEST_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BUTTON_WIDTH = getValueOrDefault(CONFIG.BUTTON_WIDTH, 100)
  CONFIG.BUTTON_HEIGHT = getValueOrDefault(CONFIG.BUTTON_HEIGHT, 25)
  CONFIG.LOCK_POSITION = getValueOrDefault(CONFIG.LOCK_POSITION, false)
  CONFIG.EXPAND_DOWN = getValueOrDefault(CONFIG.EXPAND_DOWN, false)
  CONFIG.EXPAND_RIGHT = getValueOrDefault(CONFIG.EXPAND_RIGHT, false)
  CONFIG.HIDE_EMPTY = getValueOrDefault(CONFIG.HIDE_EMPTY, false)
  CONFIG.BACKGROUND_COLOR = getValueOrDefault(CONFIG.BACKGROUND_COLOR, 0)
  CONFIG.BORDER_COLOR = getValueOrDefault(CONFIG.BORDER_COLOR, 12632256)
  CONFIG.BUTTON_LABEL = getValueOrDefault(CONFIG.BUTTON_LABEL, "Quest")
  CONFIG.ACTIVE_BUTTON_COLOR = getValueOrDefault(CONFIG.ACTIVE_BUTTON_COLOR, 8421504)
  CONFIG.ACTIVE_LABEL_COLOR = getValueOrDefault(CONFIG.ACTIVE_LABEL_COLOR, 16777215)
  CONFIG.DISABLED_BUTTON_COLOR = getValueOrDefault(CONFIG.DISABLED_BUTTON_COLOR, 6908265)
  CONFIG.DISABLED_LABEL_COLOR = getValueOrDefault(CONFIG.DISABLED_LABEL_COLOR, 8421504)
  CONFIG.SILENT_REFRESH = getValueOrDefault(CONFIG.SILENT_REFRESH, false)
  CONFIG.TRACK_PURSUER = getValueOrDefault(CONFIG.TRACK_PURSUER, true)
  CONFIG.TRACK_CRYSTAL = getValueOrDefault(CONFIG.TRACK_CRYSTAL, true)
  CONFIG.BUTTON_X = getValueOrDefault(CONFIG.BUTTON_X, GetVariable("quest_buttonx") or GetInfo(292) - CONFIG.BUTTON_WIDTH - 25)
  CONFIG.BUTTON_Y = getValueOrDefault(CONFIG.BUTTON_Y, GetVariable("quest_buttony") or GetInfo(293) - CONFIG.BUTTON_HEIGHT - 25)
  CONFIG.EXPAND_PHASES = getValueOrDefault(CONFIG.EXPAND_PHASES, 2)
  CONFIG.TIMES = getValueOrDefault(CONFIG.TIMES, { QUEST_TIME = 0, PURSUER_TIME = 0, CRYSTAL_TIME = 0 })

  pcall("DeleteVariable", "quest_buttonx")
  pcall("DeleteVariable", "quest_buttony")
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

  LINE_HEIGHT = WindowFontInfo(WIN, QUESTFONT, 1) - WindowFontInfo(WIN, QUESTFONT, 4) + 2
end

function drawMiniWindow()
  if CONFIG ~= nil and not CONFIG.HIDE_EMPTY or #TEXT_BUFFER > 0 then
    WindowShow(WIN, false)

    setSizeAndPositionToContent()
    drawToggleButton()
    drawQuestWindows()
    drawQuestText()
    drawCollapseText()
    
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

  if CONFIG.EXPAND_PHASES == 2 then
    for _, line in ipairs(TEXT_BUFFER) do
      if line.segments[1].text:sub(1, 5) == "Phase" and line.segments[2].textcolour ~= ColourNameToRGB("dimgray") then
        SECTION_STATUS[line.section] = true
        break
      end
    end
  elseif CONFIG.EXPAND_PHASES == 3 then
    for sec, _ in pairs(SECTION_STATUS) do
      SECTION_STATUS[sec] = true
    end
  end

  CURRENT_BUTTON_COLOR = CONFIG.ACTIVE_BUTTON_COLOR
  CURRENT_LABEL_COLOR = CONFIG.ACTIVE_LABEL_COLOR

  if #TEXT_BUFFER == 0 and PURSUER_TARGET == nil and CRYSTAL_TARGET == nil then
    CURRENT_BUTTON_COLOR = CONFIG.DISABLED_BUTTON_COLOR
    CURRENT_LABEL_COLOR = CONFIG.DISABLED_LABEL_COLOR
    EXPANDED = false
  end

  if #TEXT_BUFFER == 0 and PURSUER_TARGET == nil and CRYSTAL_TARGET == nil then
    EXPANDED = false
  end

  if EXPANDED then
    final_height = CONFIG.BUTTON_HEIGHT + 4

    local phase_width = WindowTextWidth(WIN, QUESTFONT, "Phase 99")

    for _, line in ipairs(TEXT_BUFFER) do
      local segments = line["segments"]
      local section = line["section"]
      local currentWidth = 0

      if line["is_header"] or SECTION_STATUS[section] then
        final_height = final_height + LINE_HEIGHT
        for _, seg in ipairs(segments) do
          currentWidth = currentWidth + WindowTextWidth(WIN, QUESTFONT, seg.text)
        end

        if line["is_header"] then
          currentWidth = currentWidth + phase_width + 4
        else
          currentWidth = currentWidth + 12
        end

        if currentWidth > final_width then
          final_width = currentWidth
        end
      end
    end

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil then 
      final_width = math.max(final_width, WindowTextWidth(WIN, QUESTFONT, "Orc Pursuer: " .. PURSUER_TARGET) + 12)
      final_height = final_height + LINE_HEIGHT 
    end
    
    if CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      final_width = math.max(final_width, WindowTextWidth(WIN, QUESTFONT, "Crystal: " .. CRYSTAL_TARGET) + 12)
      final_height = final_height + LINE_HEIGHT 
    end

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil and CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      if #TEXT_BUFFER > 0 then
        final_height = final_height + 1
      end
      final_height = final_height + 1
    elseif #TEXT_BUFFER > 0 and ((CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil) or (CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil)) then
      final_height = final_height + 1
    end
    
    if #TEXT_BUFFER > 0 then
      final_height = final_height + LINE_HEIGHT
    end
  end

  WINDOW_WIDTH = math.max(final_width, CONFIG.BUTTON_WIDTH)
  WINDOW_HEIGHT = math.max(final_height, CONFIG.BUTTON_HEIGHT)

  local new_left = 0
  local new_top = 0

  CONFIG.BUTTON_X = CONFIG.BUTTON_X or left
  CONFIG.BUTTON_Y = CONFIG.BUTTON_Y or top

  if CONFIG.EXPAND_RIGHT then
    new_left = CONFIG.BUTTON_X
  else
    new_left = CONFIG.BUTTON_X - WINDOW_WIDTH
  end

  if CONFIG.EXPAND_DOWN then
    new_top = CONFIG.BUTTON_Y
  else
    new_top = CONFIG.BUTTON_Y - WINDOW_HEIGHT
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
  if #TEXT_BUFFER > 0 or PURSUER_TARGET ~= nil or CRYSTAL_TARGET ~= nil then
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

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil and CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      if #TEXT_BUFFER > 0 then
        WindowLine(WIN, 0, bottom - LINE_HEIGHT * 2, WINDOW_WIDTH, bottom - LINE_HEIGHT * 2, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
      end
      WindowLine(WIN, 0, bottom - LINE_HEIGHT, WINDOW_WIDTH, bottom - LINE_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
    elseif #TEXT_BUFFER > 0 and ((CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil) or (CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil)) then
      WindowLine(WIN, 0, bottom - LINE_HEIGHT, WINDOW_WIDTH, bottom - LINE_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
    end

    WindowRectOp(WIN, miniwin.rect_fill, left_clear, top_clear, right_clear, bottom_clear, ColourNameToRGB("black"))
  end
end

function drawQuestText()
  if EXPANDED then
    local rooms = {}
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
      local line = TEXT_BUFFER[i]
      local segments = line["segments"]
      local section = line["section"]

      if line["is_header"] or SECTION_STATUS[section] then

        local phase_width = WindowTextWidth(WIN, QUESTFONT, "Phase 99")

        for idx, seg in ipairs(segments) do
          lineText = lineText .. seg.text
          local w = WindowTextWidth(WIN, QUESTFONT, seg.text)

          if seg.textcolour == ColourNameToRGB("dimgray") then
            WindowText(WIN, QUESTFONT_STRIKE, seg.text, x + 2, y, 0, 0, seg.textcolour)
          elseif line["is_header"] and idx == 1 and i ~= 1 then
            WindowText(WIN, QUESTFONT_UNDERLINE, Trim(seg.text), x + 6, y, 0, 0, seg.textcolour)
            WindowAddHotspot(WIN, section, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_section_click", "", miniwin.cursor_hand, 0)
          elseif line["is_header"] then
            local room_name = string.match(seg.text , "^Journey to%s+(.+)$")
            if room_name then
              if rooms[room_name] == nil then rooms[room_name] = 0 end
              local dupe_check_room_name = room_name .. "|" .. rooms[room_name]
              WindowText(WIN, QUESTFONT_UNDERLINE, seg.text, x + 2, y, 0, 0, seg.textcolour)
              WindowAddHotspot(WIN, dupe_check_room_name, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_phase_click", "", miniwin.cursor_hand, 0)
              rooms[room_name] = rooms[room_name] + 1
            else
              WindowText(WIN, QUESTFONT, seg.text, x + 2, y, 0, 0, seg.textcolour)
            end
          elseif SECTION_STATUS[section] then
            local pattern = "%[([^,%]]+),([^%]]+)%]%.?"
            local si, ei, room_name, zone_name = string.find(seg.text, pattern)
            if si then
              local before = seg.text:sub(1, si - 1) .. "["
              local after = seg.text:sub(ei + 1) .. "," .. zone_name .. "]"
              local tw = WindowTextWidth(WIN, QUESTFONT, before)
              local tn = WindowTextWidth(WIN, QUESTFONT, before .. room_name)

              if rooms[room_name] == nil then rooms[room_name] = 0 end
              local dupe_check_room_name = room_name .. "|" .. rooms[room_name]

              WindowText(WIN, QUESTFONT, before, x + 2, y, 0, 0, seg.textcolour)
              WindowText(WIN, QUESTFONT_UNDERLINE, room_name, x + tw + 2, y, 0, 0, seg.textcolour)
              WindowText(WIN, QUESTFONT, after, x + tn + 2, y, 0, 0, seg.textcolour)
              WindowAddHotspot(WIN, dupe_check_room_name, x + tw + 2, y, x + tn + 2, y + LINE_HEIGHT, "", "", "", "", "quest_phase_click", "", miniwin.cursor_hand, 0)
              rooms[room_name] = rooms[room_name] + 1
            else
              WindowText(WIN, QUESTFONT, seg.text, x + 2, y, 0, 0, seg.textcolour)
            end
          end

          if i == 1 and seg.text == CURRENT_INFO.quest_number then
            WindowAddHotspot(WIN, "goto_annwn", x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_number_click", "Open link to annwn.info page", miniwin.cursor_hand, 0)
          end
          
          if line["is_header"] and idx == 1 and i ~= 1 then
            x = phase_width + 12
          else
            x = x + w
          end
        end

        if #lineText > 0 then
          y = y + LINE_HEIGHT
        end
      end
    end

    if #TEXT_BUFFER > 0 then
      y = y + LINE_HEIGHT
    end

    local prefix_length = WindowTextWidth(WIN, QUESTFONT, "Orc Pursuer: ")
    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil and CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      y = y + 1
      WindowText(WIN, QUESTFONT, "Orc Pursuer: ", 6, y, 0, 0, ColourNameToRGB("silver"))
      WindowText(WIN, QUESTFONT, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, ColourNameToRGB("white"))
      prefix_length = WindowTextWidth(WIN, QUESTFONT, "Crystal: ")
      y = y + 1
      WindowText(WIN, QUESTFONT, "Crystal: ", 6, y + LINE_HEIGHT, 0, 0, ColourNameToRGB("silver"))
      WindowText(WIN, QUESTFONT, CRYSTAL_TARGET, 6 + prefix_length, y + LINE_HEIGHT, 0, 0, ColourNameToRGB("white"))
    elseif CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil then
      y = y + 1
      WindowText(WIN, QUESTFONT, "Orc Pursuer: ", 6, y, 0, 0, ColourNameToRGB("silver"))
      WindowText(WIN, QUESTFONT, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, ColourNameToRGB("white"))
    elseif CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      prefix_length = WindowTextWidth(WIN, QUESTFONT, "Crystal: ")
      y = y + 1
      WindowText(WIN, QUESTFONT, "Crystal: ", 6, y, 0, 0, ColourNameToRGB("silver"))
      WindowText(WIN, QUESTFONT, CRYSTAL_TARGET, 6 + prefix_length, y, 0, 0, ColourNameToRGB("white"))
    end
  end
end

function drawCollapseText()
  if EXPANDED and #TEXT_BUFFER > 0 then
    local single_width = WindowTextWidth(WIN, QUESTFONT, "[+]")
    local collapse_width = WindowTextWidth(WIN, QUESTFONT, "[+] [-]")
    local expand_x = WINDOW_WIDTH - collapse_width
    local collapse_x = WINDOW_WIDTH - single_width
    local y = WINDOW_HEIGHT - LINE_HEIGHT

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil then y = y - LINE_HEIGHT end
    if CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then y = y - LINE_HEIGHT end

    WindowText(WIN, QUESTFONT_UNDERLINE, "[+] [-]", expand_x, y, 0, 0, CONFIG.QUEST_FONT.colour)
    WindowAddHotspot(WIN, "expand_all", expand_x, y, expand_x + single_width, y + LINE_HEIGHT, "", "", "", "", "expand_collapse_click", "", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, "collapse_all", collapse_x, y, WINDOW_WIDTH, y + LINE_HEIGHT, "", "", "", "", "expand_collapse_click", "", miniwin.cursor_hand, 0)
  end
end

function SetQuestInfo(quest_num, quest_name, annwn_id)
  CURRENT_INFO = { quest_number = quest_num, quest_name = quest_name, annwn_id = annwn_id }
end

function AddLine(segments, section, is_header)
  if CONFIG == nil then
    InitializeMiniWindow()
  end

  EXPANDED = true

  if TEXT_BUFFER == nil then 
    clearMiniWindow()
  end

  if SECTION_STATUS[section] == nil then
    SECTION_STATUS[section] = false
  else
    SECTION_STATUS[section] = SECTION_STATUS[section]
  end
  
  table.insert(TEXT_BUFFER, { segments = segments, section = section, is_header = is_header })

  drawMiniWindow()
end

function SetPursuerTarget(target)
  if CONFIG.TRACK_PURSUER then
    PURSUER_TARGET = target
    COLLECTED_PART = nil
    if PURSUER_TARGET ~= nil then EXPANDED = true end
    drawMiniWindow()
  end
end

function SetCrystalTarget(target)
  if CONFIG.TRACK_CRYSTAL then
    CRYSTAL_TARGET = target
    if CRYSTAL_TARGET ~= nil then EXPANDED = true end
    drawMiniWindow()
  end
end

function CheckBodyPartDrop(part, victim)
  if PURSUER_TARGET ~= nil and PURSUER_TARGET:lower():find(Trim(victim:lower())) ~= nil then
    Send("get '" .. part .. "'")
    COLLECTED_PART = part
  end
end

function expand_collapse_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if hotspot_id == "expand_all" then
      for sec, _ in pairs(SECTION_STATUS) do
        SECTION_STATUS[sec] = true
      end
    elseif hotspot_id == "collapse_all" then
      for sec, _ in pairs(SECTION_STATUS) do
        SECTION_STATUS[sec] = false
      end
    end
    drawMiniWindow()
  end
end

function quest_phase_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    Execute("mapper find " .. hotspot_id:match("^(.-)|") or hotspot_id)
  end
end

function quest_section_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    SECTION_STATUS[hotspot_id] = not SECTION_STATUS[hotspot_id]
    drawMiniWindow()
  end
end

function quest_button_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if #TEXT_BUFFER > 0 or PURSUER_TARGET ~= nil or CRYSTAL_TARGET ~= nil then
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

function quest_number_click(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if CURRENT_INFO ~= nil and CURRENT_INFO.annwn_id ~= nil and Trim(CURRENT_INFO.annwn_id) ~= "" then
      OpenBrowser("https://annwn.info/quest/" .. CURRENTINFO.annwn_id)
    elseif CURRENT_INFO ~= nil and CURRENT_INFO.quest_name ~= nil and CURRENT_INFO.quest_name ~= "" then
      OpenBrowser("https://annwn.info/quest/search/?search=quest&keyword=" .. CURRENT_INFO.quest_name:gsub(" ", "+"))
    end
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
  SaveState()
end

function ShowTimes()
  doTimeString(CONFIG.TIMES.QUEST_TIME, "You can get another quest")
  doTimeString(CONFIG.TIMES.PURSUER_TIME, "You can get another pursuer target")
  doTimeString(CONFIG.TIMES.CRYSTAL_TIME, "You can get another crystal map")
end

function SetQuestTime(alyrian_time)
  if alyrian_time ~= nil then
    CONFIG.TIMES.QUEST_TIME = os.time() + (tonumber(alyrian_time) / 4) * 60
  else
    CONFIG.TIMES.QUEST_TIME = os.time() + 300
  end 
  saveMiniWindow()
end

function SetPursuerTime()
  CONFIG.TIMES.PURSUER_TIME = os.time() + 60 * 20
  saveMiniWindow()
end

function SetCrystalTime()
  CONFIG.TIMES.CRYSTAL_TIME = os.time() + 60 * 120
  saveMiniWindow()
end

function ShowOrcPursuerOptions()
  if PURSUER_TARGET ~= nil and Trim(PURSUER_TARGET) ~= "" then
    if COLLECTED_PART ~= nil and Trim(COLLECTED_PART) ~= "" then
      Send("give '" .. COLLECTED_PART .. "' orc")
    else
      Note("You are still looking for a body part from " .. PURSUER_TARGET)
    end
  else
    local color, timer_string = getTimerColorAndString(CONFIG.TIMES.PURSUER_TIME)
    Tell("You can ")
    Hyperlink("!!" .. GetPluginID() .. ":getPursuerTarget()", "[get a target]", "", "silver", "black", false)
    Tell(" from the orc pursuer")
    ColourTell(color, "black", timer_string)
    Note(".")
  end
end

function getPursuerTarget()
  Send("sayto orc yes")
  Send("nod orc")
end

function doTimeString(time, text)
  local color, timer_string = getTimerColorAndString(time)
  Tell("* ")
  ColourTell("silver", "black", text)
  ColourTell(color, "black", timer_string)
  ColourTell("silver", "black", ".")
  Note("")
end

function getTimerColorAndString(time)
  if (time == nil) then
    return "green", " right now probably"
  else
    local now = os.time()
    local diff = os.difftime(time, now)

    if diff < 0 then
      return "green", " right now"
    else
      local seconds = diff % 60
      local minutes = math.floor(diff / 60) % 60
      local hours = math.floor(diff / 3600) % 24
  
      local color = "red"
      if (minutes < 3) then
        color = "yellow"
      end

      if hours > 0 then
        return color, string.format(" in %02d hours, %02d minutes, %02d seconds", hours, minutes, seconds)
      end
      
      return color, string.format(" in %02d minutes, %02d seconds", minutes, seconds)
    end
  end
end

function isSilentRefreshEnabled()
  return CONFIG.SILENT_REFRESH
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
      ANCHOR = { type = "list", value = "None", raw_value = 1, list = ANCHOR_LIST },
      SILENT_REFRESH = { type = "bool", raw_value = CONFIG.SILENT_REFRESH },
      TRACK_PURSUER = { type = "bool", raw_value = CONFIG.TRACK_PURSUER },
      TRACK_CRYSTAL = { type = "bool", raw_value = CONFIG.TRACK_CRYSTAL },
      BUTTON_X = { type = "number", raw_value = CONFIG.BUTTON_X, min = 0, max = GetInfo(281) - 50 },
      BUTTON_Y = { type = "number", raw_value = CONFIG.BUTTON_Y, min = 0, max = GetInfo(280) - 50 },
      EXPAND_PHASES = { type = "list", value = getExpandPhasesText(CONFIG.EXPAND_PHASES), raw_value = CONFIG.EXPAND_PHASES, list = EXPAND_LIST },
    }
  }
  
  config_window.Show(config, configureDone)
end

function getExpandPhasesText(opt)
  if opt == 1 then
    return "None"
  elseif opt == 2 then
    return "First Phase"
  elseif opt == 3 then
    return "All Phases"
  end
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
    CONFIG.BUTTON_X = 10
    CONFIG.BUTTON_Y = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Window)" then 
    CONFIG.BUTTON_X = 10
    CONFIG.BUTTON_Y = GetInfo(280) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Top Right (Window)" then
    CONFIG.BUTTON_X = GetInfo(281) - CONFIG.BUTTON_WIDTH - 10
    CONFIG.BUTTON_Y = 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Bottom Right (Window)" then
    CONFIG.BUTTON_X = GetInfo(281) - CONFIG.BUTTON_WIDTH - 10
    CONFIG.BUTTON_Y = GetInfo(280) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = false
  elseif anchor == "Top Left (Output)" then
    CONFIG.BUTTON_X = GetInfo(290) + 10
    CONFIG.BUTTON_Y = GetInfo(291) + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = true
  elseif anchor == "Bottom Left (Output)" then
    CONFIG.BUTTON_X = GetInfo(290) + 10
    CONFIG.BUTTON_Y = GetInfo(293) - 10
    CONFIG.EXPAND_DOWN = false
    CONFIG.EXPAND_RIGHT = true
  elseif anchor ==  "Top Right (Output)" then
    CONFIG.BUTTON_X = GetInfo(292) - 10
    CONFIG.BUTTON_Y = GetInfo(291) + 10
    CONFIG.EXPAND_DOWN = true
    CONFIG.EXPAND_RIGHT = false
  elseif anchor ==  "Bottom Right (Output)" then
    CONFIG.BUTTON_X = GetInfo(292) - 10
    CONFIG.BUTTON_Y = GetInfo(293) - 10
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

function getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
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

function debug()
  Note("All Segments: ")
  for _, line in ipairs(TEXT_BUFFER) do
    for _, seg in ipairs(line.segments) do
      Tell(seg.text)
    end
    Note("")
  end
  Note("")
  Note("Section status:")
  for sec, show in pairs(SECTION_STATUS) do
    if show then
      Note(sec .. " - yes")
    else
      Note(sec .. " - no")
    end
  end
end