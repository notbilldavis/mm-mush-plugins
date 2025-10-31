local serializer_installed, serialization_helper = pcall(require, "serializationhelper")
local config_installed, config_window = pcall(require, "configuration_miniwindow")
local const_installed, consts = pcall(require, "consthelper")

local initialize, clear, close, save, getConfiguration, onConfigureDone, setQuestInfo, addLine, 
  setPursuerTarget, setCrystalTarget, checkBodyPartDrop, showTimes, setQuestTime, setPursuerTime,
  setCrystalTime, showPursuerOptions, isSilentRefreshEnabled, isAutoUpdateEnabled, getQuestTime,
  isAutoLookupEnabled, getPursuerTime, isLookupCrystalEnabled, setHasCrystal
local load, create, draw, setSizeAndPositionToContent, drawToggleButton, drawQuestWindows, drawQuestText,
  drawCollapseText, adjustAnchor, doTimeString, getTimerColorAndString, getExpandPhasesText

local WIN = GetPluginID()
local BUTTONFONT = WIN .. "_button_font"
local QUESTFONT = WIN .. "_quest_font"
local QUESTFONT_STRIKE = QUESTFONT .. "_strike"
local QUESTFONT_UNDERLINE = QUESTFONT .. "_underline"

local CONFIG = nil
local POSITION = nil

local TEXT_BUFFER = { }
local FORMATTED_LINES = { }
local SECTION_STATUS = { }

local CURRENT_BUTTON_COLOR
local CURRENT_LABEL_COLOR 

local LINE_HEIGHT = nil
local DRAG_X = nil
local DRAG_Y = nil
local EXPANDED = true

local CURRENT_INFO = nil
local PURSUER_TARGET = nil
local CRYSTAL_TARGET = nil
local COLLECTED_PART = nil
local HAS_CRYSTAL = false

local SERIALIZE_TAGS = { CONFIG = "quest_config", POSITION = "quest_position" }
local EXPAND_DIRECTION_LIST = { "Up/Left", "Up/Right", "Down/Left", "Down/Right" }
local EXPAND_QUEST_LIST = { "1: Never", "2: First Phase", "3: All Phases" }
local ANCHOR_LIST = { 
  "0: None", 
  "1: Top Left (Window)", "2: Bottom Left (Window)", "3: Top Right (Window)", "4: Bottom Right (Window)", 
  "5: Top Left (Output)", "6: Bottom Left (Output)", "7: Top Right (Output)", "8: Bottom Right (Output)",
}

initialize = function()
  load()
  create()
  draw()
end

load = function()
  CONFIG = serialization_helper.GetSerializedVariable(SERIALIZE_TAGS.CONFIG)
  POSITION = serialization_helper.GetSerializedVariable(SERIALIZE_TAGS.POSITION)
  
  CONFIG.BUTTON_FONT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.QUEST_FONT = serialization_helper.GetValueOrDefault(CONFIG.QUEST_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BUTTON_WIDTH = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_WIDTH, 100)
  CONFIG.BUTTON_HEIGHT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_HEIGHT, 25)
  CONFIG.LOCK_POSITION = serialization_helper.GetValueOrDefault(CONFIG.LOCK_POSITION, false)
  CONFIG.EXPAND_DOWN = serialization_helper.GetValueOrDefault(CONFIG.EXPAND_DOWN, false)
  CONFIG.EXPAND_RIGHT = serialization_helper.GetValueOrDefault(CONFIG.EXPAND_RIGHT, false)
  CONFIG.HIDE_EMPTY = serialization_helper.GetValueOrDefault(CONFIG.HIDE_EMPTY, false)
  CONFIG.BACKGROUND_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BACKGROUND_COLOR, 0)
  CONFIG.BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BORDER_COLOR, 12632256)
  CONFIG.BUTTON_LABEL = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_LABEL, "Quest")
  CONFIG.ACTIVE_BUTTON_COLOR = serialization_helper.GetValueOrDefault(CONFIG.ACTIVE_BUTTON_COLOR, 8421504)
  CONFIG.ACTIVE_LABEL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.ACTIVE_LABEL_COLOR, 16777215)
  CONFIG.DISABLED_BUTTON_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DISABLED_BUTTON_COLOR, 6908265)
  CONFIG.DISABLED_LABEL_COLOR = serialization_helper.GetValueOrDefault(CONFIG.DISABLED_LABEL_COLOR, 8421504)
  CONFIG.SILENT_REFRESH = serialization_helper.GetValueOrDefault(CONFIG.SILENT_REFRESH, true)
  CONFIG.TRACK_PURSUER = serialization_helper.GetValueOrDefault(CONFIG.TRACK_PURSUER, true)
  CONFIG.TRACK_CRYSTAL = serialization_helper.GetValueOrDefault(CONFIG.TRACK_CRYSTAL, true)
  CONFIG.EXPAND_PHASES = serialization_helper.GetValueOrDefault(CONFIG.EXPAND_PHASES, 2)
  CONFIG.TIMES = serialization_helper.GetValueOrDefault(CONFIG.TIMES, { QUEST_TIME = 0, PURSUER_TIME = 0, CRYSTAL_TIME = 0 })
  CONFIG.AUTO_LOOKUP = serialization_helper.GetValueOrDefault(CONFIG.AUTO_LOOKUP, true)
  CONFIG.LOOKUP_CRYSTAL = serialization_helper.GetValueOrDefault(CONFIG.LOOKUP_CRYSTAL, true)

  PURSUER_TARGET = serialization_helper.GetValueOrDefault(CONFIG.PURSUER_TARGET, nil)

  POSITION.WINDOW_LEFT = serialization_helper.GetValueOrDefault(POSITION.WINDOW_LEFT, consts.GetOutputRight() - CONFIG.BUTTON_WIDTH - 10)
  POSITION.WINDOW_TOP = serialization_helper.GetValueOrDefault(POSITION.WINDOW_TOP, consts.GetOutputBottom() - CONFIG.BUTTON_HEIGHT - 10)
  POSITION.Z_POSITION = serialization_helper.GetValueOrDefault(POSITION.Z_POSITION, 1000)
end

create = function()
  if CONFIG == nil then return end

  local buttonfont = CONFIG["BUTTON_FONT"]
  local questfont = CONFIG["QUEST_FONT"]

  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, BUTTONFONT, buttonfont.name, buttonfont.size, 
    serialization_helper.ConvertToBool(buttonfont.bold), 
    serialization_helper.ConvertToBool(buttonfont.italic), 
    serialization_helper.ConvertToBool(buttonfont.underline), 
    serialization_helper.ConvertToBool(buttonfont.strikeout))

  WindowFont(WIN, QUESTFONT, questfont.name, questfont.size)
  WindowFont(WIN, QUESTFONT_STRIKE, questfont.name, questfont.size, false, false, false, true)
  WindowFont(WIN, QUESTFONT_UNDERLINE, questfont.name, questfont.size, false, false, true, false)

  LINE_HEIGHT = WindowFontInfo(WIN, QUESTFONT, 1) - WindowFontInfo(WIN, QUESTFONT, 4) + 2
end

draw = function()
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

setSizeAndPositionToContent = function()
  local left = math.max(WindowInfo(WIN, 1), 0)
  local top = math.max(WindowInfo(WIN, 2), 0)
  local right = left + WindowInfo(WIN, 3)
  local bottom = top + WindowInfo(WIN, 4)

  local final_width = CONFIG.BUTTON_WIDTH
  local final_height = CONFIG.BUTTON_HEIGHT

  if TEXT_BUFFER == nil then
    TEXT_BUFFER = { }
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
  if #TEXT_BUFFER > 0 or PURSUER_TARGET ~= nil or CRYSTAL_TARGET ~= nil then
    cursor = miniwin.cursor_hand
  end

  WindowAddHotspot(WIN, "quest_button", left, top, button_right, bottom, "", "", "", "", "quest_buttonClick", "", cursor, 0)

  if not CONFIG.LOCK_POSITION then
    WindowRectOp(WIN, miniwin.rect_fill, button_right, top, right, bottom, CURRENT_BUTTON_COLOR)
    WindowLine(WIN, button_right + 3, top + 8, right - 3, top + 8, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 12, right - 3, top + 12, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)
    WindowLine(WIN, button_right + 3, top + 16, right - 3, top + 16, CURRENT_LABEL_COLOR, miniwin.pen_solid, 1)

    WindowAddHotspot(WIN, "drag_" .. WIN, button_right, top, right, bottom, "", "", "quest_dragMouseDown", "", "", "", 10, 0)
    WindowDragHandler (WIN, "drag_" .. WIN, "quest_dragMouseMove", "quest_dragMouseRelease", 0)
  end
end

function quest_dragMouseDown(flags, hotspot_id)
  DRAG_X = WindowInfo(WIN, 14)
  DRAG_Y = WindowInfo(WIN, 15)
end

function quest_dragMouseMove(flags, hotspot_id)
  local pos_x = clamp(WindowInfo(WIN, 17) - DRAG_X, 0, GetInfo(281) - POSITION.WINDOW_WIDTH)
  local pos_y = clamp(WindowInfo(WIN, 18) - DRAG_Y, 0, GetInfo(280) - LINE_HEIGHT)

  SetCursor(miniwin.cursor_hand)
  WindowPosition(WIN, pos_x, pos_y, 0, miniwin.create_absolute_location);
end

function quest_dragMouseRelease(flags, hotspot_id)
  Repaint()
  save()
end

drawQuestWindows = function()
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

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil and CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      if #TEXT_BUFFER > 0 then
        WindowLine(WIN, 0, bottom - LINE_HEIGHT * 2, POSITION.WINDOW_WIDTH, bottom - LINE_HEIGHT * 2, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
      end
      WindowLine(WIN, 0, bottom - LINE_HEIGHT, POSITION.WINDOW_WIDTH, bottom - LINE_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
    elseif #TEXT_BUFFER > 0 and ((CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil) or (CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil)) then
      WindowLine(WIN, 0, bottom - LINE_HEIGHT, POSITION.WINDOW_WIDTH, bottom - LINE_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, 1)
    end

    WindowRectOp(WIN, miniwin.rect_fill, left_clear, top_clear, right_clear, bottom_clear, consts.black)
  end
end

drawQuestText = function()
  if EXPANDED then
    local rooms = {}
    local y = 4
    if CONFIG.EXPAND_DOWN then
      y = y + CONFIG.BUTTON_HEIGHT
    end

    for i = 1, #TEXT_BUFFER do
      local x = 4
      if y + LINE_HEIGHT > POSITION.WINDOW_HEIGHT then
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

          if seg.textcolour == consts.dimgray then
            WindowText(WIN, QUESTFONT_STRIKE, seg.text, x + 2, y, 0, 0, seg.textcolour)
          elseif line["is_header"] and idx == 1 and i ~= 1 then
            WindowText(WIN, QUESTFONT_UNDERLINE, Trim(seg.text), x + 6, y, 0, 0, seg.textcolour)
            WindowAddHotspot(WIN, section, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_sectionClick", "", miniwin.cursor_hand, 0)
          elseif line["is_header"] then
            local room_name = string.match(seg.text , "^Journey to%s+(.+)$")
            if room_name then
              if rooms[room_name] == nil then rooms[room_name] = 0 end
              local dupe_check_room_name = room_name .. "|" .. rooms[room_name]
              WindowText(WIN, QUESTFONT_UNDERLINE, seg.text, x + 2, y, 0, 0, seg.textcolour)
              WindowAddHotspot(WIN, dupe_check_room_name, x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_phaseClick", "", miniwin.cursor_hand, 0)
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
              WindowAddHotspot(WIN, dupe_check_room_name, x + tw + 2, y, x + tn + 2, y + LINE_HEIGHT, "", "", "", "", "quest_phaseClick", "", miniwin.cursor_hand, 0)
              rooms[room_name] = rooms[room_name] + 1
            else
              WindowText(WIN, QUESTFONT, seg.text, x + 2, y, 0, 0, seg.textcolour)
            end
          end

          if i == 1 and seg.text == CURRENT_INFO.quest_number then
            WindowAddHotspot(WIN, "goto_annwn", x, y, x + w, y + LINE_HEIGHT, "", "", "", "", "quest_numberClick", "Open link to annwn.info page", miniwin.cursor_hand, 0)
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
      if y > 4 + CONFIG.BUTTON_HEIGHT then y = y + 3 else y = y + 1 end
      WindowText(WIN, QUESTFONT, "Orc Pursuer: ", 6, y, 0, 0, consts.silver)
      if (COLLECTED_PART ~= nil) then
        WindowText(WIN, QUESTFONT_STRIKE, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, consts.dimgray)
      else
        WindowText(WIN, QUESTFONT, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, consts.white)
      end
      prefix_length = WindowTextWidth(WIN, QUESTFONT, "Crystal: ")
      y = y + 3
      WindowText(WIN, QUESTFONT, "Crystal: ", 6, y + LINE_HEIGHT, 0, 0, consts.silver)
      if HAS_CRYSTAL then
        WindowText(WIN, QUESTFONT_STRIKE, CRYSTAL_TARGET, 6 + prefix_length, y + LINE_HEIGHT, 0, 0, consts.dimgray)
      else
        WindowText(WIN, QUESTFONT, CRYSTAL_TARGET, 6 + prefix_length, y + LINE_HEIGHT, 0, 0, consts.white)
      end
    elseif CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil then
      if y > 4 + CONFIG.BUTTON_HEIGHT then y = y + 3 else y = y + 1 end
      WindowText(WIN, QUESTFONT, "Orc Pursuer: ", 6, y, 0, 0, consts.silver)
      if (COLLECTED_PART ~= nil) then
        WindowText(WIN, QUESTFONT_STRIKE, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, consts.dimgray)
      else
        WindowText(WIN, QUESTFONT, PURSUER_TARGET, 6 + prefix_length, y, 0, 0, consts.white)
      end
    elseif CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then
      prefix_length = WindowTextWidth(WIN, QUESTFONT, "Crystal: ")
      if y > 4 + CONFIG.BUTTON_HEIGHT then y = y + 3 else y = y + 1 end
      WindowText(WIN, QUESTFONT, "Crystal: ", 6, y, 0, 0, consts.silver)
      if HAS_CRYSTAL then
        WindowText(WIN, QUESTFONT_STRIKE, CRYSTAL_TARGET, 6 + prefix_length, y, 0, 0, consts.dimgray)
      else
        WindowText(WIN, QUESTFONT, CRYSTAL_TARGET, 6 + prefix_length, y, 0, 0, consts.white)
      end
    end
  end
end

drawCollapseText = function()
  if EXPANDED and #TEXT_BUFFER > 0 then
    local single_width = WindowTextWidth(WIN, QUESTFONT, "[+]")
    local collapse_width = WindowTextWidth(WIN, QUESTFONT, "[+] [-]")
    local expand_x = POSITION.WINDOW_WIDTH - collapse_width
    local collapse_x = POSITION.WINDOW_WIDTH - single_width
    local y = POSITION.WINDOW_HEIGHT - LINE_HEIGHT

    if CONFIG.TRACK_PURSUER and PURSUER_TARGET ~= nil then y = y - LINE_HEIGHT end
    if CONFIG.TRACK_CRYSTAL and CRYSTAL_TARGET ~= nil then y = y - LINE_HEIGHT end

    WindowText(WIN, QUESTFONT_UNDERLINE, "[+] [-]", expand_x, y, 0, 0, CONFIG.QUEST_FONT.colour)
    WindowAddHotspot(WIN, "expand_all", expand_x, y, expand_x + single_width, y + LINE_HEIGHT, "", "", "", "", "quest_expandCollapseClick", "", miniwin.cursor_hand, 0)
    WindowAddHotspot(WIN, "collapse_all", collapse_x, y, POSITION.WINDOW_WIDTH, y + LINE_HEIGHT, "", "", "", "", "quest_expandCollapseClick", "", miniwin.cursor_hand, 0)
  end
end

setQuestInfo = function(quest_num, quest_name, annwn_id)
  CURRENT_INFO = { quest_number = quest_num, quest_name = quest_name, annwn_id = annwn_id }
end

addLine = function(segments, section, is_header)
  if CONFIG == nil then
    initialize()
  end

  EXPANDED = true

  if TEXT_BUFFER == nil then 
    clear()
  end

  if SECTION_STATUS[section] == nil then
    SECTION_STATUS[section] = false
  else
    SECTION_STATUS[section] = SECTION_STATUS[section]
  end
  
  table.insert(TEXT_BUFFER, { segments = segments, section = section, is_header = is_header })

  if CONFIG.EXPAND_PHASES == 2 then
    for _, line in ipairs(TEXT_BUFFER) do
      if line.segments[1].text:sub(1, 5) == "Phase" and line.segments[2].textcolour ~= consts.dimgray then
        SECTION_STATUS[line.section] = true
        break
      end
    end
  elseif CONFIG.EXPAND_PHASES == 3 then
    for sec, _ in pairs(SECTION_STATUS) do
      SECTION_STATUS[sec] = true
    end
  end

  draw()
end

setPursuerTarget = function(target)
  if CONFIG.TRACK_PURSUER then
    PURSUER_TARGET = target
    CONFIG.PURSUER_TARGET = target
    COLLECTED_PART = nil
    if PURSUER_TARGET ~= nil then EXPANDED = true end
    draw()
    save()
  end
end

setCrystalTarget = function(target)
  if CONFIG.TRACK_CRYSTAL then
    CRYSTAL_TARGET = target
    HAS_CRYSTAL = false
    if CRYSTAL_TARGET ~= nil then EXPANDED = true end
    draw()
  end
end

checkBodyPartDrop = function(part, victim)
  if PURSUER_TARGET ~= nil and PURSUER_TARGET:lower():find(Trim(victim:lower())) ~= nil then
    part = part:match("^[^%-]+") or part
    Send("get '" .. part .. "'")
    COLLECTED_PART = part
    BroadcastPlugin(3, "off")
    draw()
  end
end

function quest_expandCollapseClick(flags, hotspot_id)
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
    draw()
  end
end

function quest_phaseClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    Execute("mapper find " .. hotspot_id:match("^(.-)|") or hotspot_id)
  end
end

function quest_sectionClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    SECTION_STATUS[hotspot_id] = not SECTION_STATUS[hotspot_id]
    draw()
  end
end

function quest_buttonClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if #TEXT_BUFFER > 0 or PURSUER_TARGET ~= nil or CRYSTAL_TARGET ~= nil then
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
    menu_items = menu_items .. " < |-| Configure"
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), menu_items)
    if result == nil or result == "" then return end
    if result == "Lock Position" then
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

function quest_numberClick(flags, hotspot_id)
  if flags == miniwin.hotspot_got_lh_mouse then
    if CURRENT_INFO ~= nil and CURRENT_INFO.annwn_id ~= nil and Trim(CURRENT_INFO.annwn_id) ~= "" then
      OpenBrowser("https://annwn.info/quest/" .. CURRENT_INFO.annwn_id)
    elseif CURRENT_INFO ~= nil and CURRENT_INFO.quest_name ~= nil and CURRENT_INFO.quest_name ~= "" then
      OpenBrowser("https://annwn.info/quest/search/?search=quest&keyword=" .. CURRENT_INFO.quest_name:gsub(" ", "+"))
    end
  end
end

clear = function(what)
  if what == "quest" then
    TEXT_BUFFER = {}
    FORMATTED_LINES = {}
  elseif what == "pursuer" then
    PURSUER_TARGET = nil
    CONFIG.PURSUER_TARGET = nil
    save()
  elseif what == "crystal" then
    CRYSTAL_TARGET = nil
    HAS_CRYSTAL = false
  end
  
  WindowDeleteAllHotspots(WIN)
  draw()
end

close = function()
  save()
  CONFIG = nil
  WindowShow(WIN, false)
end

save = function()
  serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.CONFIG, CONFIG)
  serialization_helper.SaveSerializedVariable(SERIALIZE_TAGS.POSITION, POSITION)
end

showTimes = function()
  doTimeString(CONFIG.TIMES.QUEST_TIME, "You can get another quest")
  doTimeString(CONFIG.TIMES.PURSUER_TIME, "You can get another pursuer target")
  doTimeString(CONFIG.TIMES.CRYSTAL_TIME, "You can get another crystal map")
end

getQuestTime = function()
  if CONFIG ~= nil and CONFIG.TIMES ~= nil and CONFIG.TIMES.QUEST_TIME ~= nil then
    return CONFIG.TIMES.QUEST_TIME
  end
  return nil
end

getPursuerTime = function()
  if CONFIG ~= nil and CONFIG.TIMES ~= nil and CONFIG.TIMES.PURSUER_TIME ~= nil then
    return CONFIG.TIMES.PURSUER_TIME
  end
  return nil
end

setQuestTime = function(alyrian_time)
  if alyrian_time ~= nil then
    CONFIG.TIMES.QUEST_TIME = os.time() + (tonumber(alyrian_time) / 4) * 60
  else
    CONFIG.TIMES.QUEST_TIME = os.time() + 300
  end 
  save()
end

setPursuerTime = function()
  CONFIG.TIMES.PURSUER_TIME = os.time() + 60 * 20
  save()
end

setCrystalTime = function()
  CONFIG.TIMES.CRYSTAL_TIME = os.time() + 60 * 120
  save()
end

showPursuerOptions = function()
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

doTimeString = function(time, text)
  local color, timer_string = getTimerColorAndString(time)
  Tell("* ")
  ColourTell("silver", "black", text)
  ColourTell(color, "black", timer_string)
  ColourTell("silver", "black", ".")
  Note("")
end

getTimerColorAndString = function(time)
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

isSilentRefreshEnabled = function()
  return CONFIG.SILENT_REFRESH
end

getExpandPhasesText = function(opt)
  if opt == 1 then
    return "None"
  elseif opt == 2 then
    return "First Phase"
  elseif opt == 3 then
    return "All Phases"
  end
end

setHasCrystal = function(has)
  HAS_CRYSTAL = has
end

getConfiguration = function()
  local expand_direction = (CONFIG.EXPAND_DOWN and "Down" or "Up") .. "/" .. (CONFIG.EXPAND_RIGHT and "Right" or "Left")
  
  return {
    OPTIONS = {
      AUTO_LOOKUP = config_window.CreateBoolOption(-1, "Auto-Lookup", CONFIG.AUTO_LOOKUP, "Look up the quest on annwn when you get it, could have a lag if you would rather do it manually."),
      LOOKUP_CRYSTAL = config_window.CreateBoolOption(0, "Lookup Crystal", CONFIG.LOOKUP_CRYSTAL, "Look up the crystal map on OOC when you look at the map, could have a lag if you would rather do it manually."),
      HIDE_EMPTY = config_window.CreateBoolOption(1, "Hide Inactive", CONFIG.ENABLED, "Will hide the button entirely if there is nothing to show."),
      LOCK_POSITION = config_window.CreateBoolOption(2, "Lock Position", CONFIG.LOCK_POSITION, "Disable dragging to move the panel."),
      EXPAND = config_window.CreateListOption(3, "Expand Direction", expand_direction, EXPAND_DIRECTION_LIST, "Set the direction the window will expand from the button."),
      SILENT_REFRESH = config_window.CreateBoolOption(4, "Silent Refresh", CONFIG.SILENT_REFRESH, "Try to silently update the progress when you complete parts."),
      TRACK_PURSUER = config_window.CreateBoolOption(5, "Orc Pursuer", CONFIG.TRACK_PURSUER, "Keep track of your current target for the orc pursuer."),
      TRACK_CRYSTAL = config_window.CreateBoolOption(6, "Crystal Guild", CONFIG.TRACK_CRYSTAL, "Look up coordinates and keep track of the location when you look at a map."),
      EXPAND_PHASES = config_window.CreateListOption(7, "Expand Phases", EXPAND_QUEST_LIST[CONFIG.EXPAND_PHASES], EXPAND_QUEST_LIST, "Different ways to expand the quest phases in the window.")
    },
    BUTTON = {
      BUTTON_FONT = config_window.CreateFontOption(1, "Button Font", CONFIG.BUTTON_FONT, "The font used for the button."),
      QUEST_FONT = config_window.CreateFontOption(2, "Quest Font", CONFIG.QUEST_FONT, "The font used for the quest."),
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
      local expand = utils.split(EXPAND_LIST[config.raw_value], '/')
      if expand[1] == "Up" then CONFIG.EXPAND_DOWN = false
      else CONFIG.EXPAND_DOWN = true end
      if expand[2] == "Left" then CONFIG.EXPAND_RIGHT = false
      else CONFIG.EXPAND_RIGHT = true end
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

isAutoUpdateEnabled = function()
  return CONFIG.AUTOUPDATE
end

isAutoLookupEnabled = function()
  return CONFIG.AUTO_LOOKUP
end

isLookupCrystalEnabled = function()
  return CONFIG.LOOKUP_CRYSTAL
end

return {
  Initialize = initialize, 
  Clear = clear, 
  Close = close, 
  Save = save, 
  GetConfiguration = getConfiguration, 
  OnConfigureDone = onConfigureDone, 
  SetQuestInfo = setQuestInfo, 
  AddLine = addLine, 
  SetPursuerTarget = setPursuerTarget, 
  SetCrystalTarget = setCrystalTarget, 
  CheckBodyPartDrop = checkBodyPartDrop, 
  ShowTimes = showTimes, 
  SetQuestTime = setQuestTime, 
  SetPursuerTime = setPursuerTime,
  SetCrystalTime = setCrystalTime, 
  ShowPursuerOptions = showPursuerOptions, 
  IsSilentRefreshEnabled = isSilentRefreshEnabled, 
  IsAutoUpdateEnabled = isAutoUpdateEnabled,
  GetQuestTime = getQuestTime,
  GetPursuerTime = getPursuerTime,
  IsAutoLookupEnabled = isAutoLookupEnabled,
  IsLookupCrystalEnabled = isLookupCrystalEnabled,
  SetHasCrystal = setHasCrystal
}