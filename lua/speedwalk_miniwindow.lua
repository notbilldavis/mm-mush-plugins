local const_installed, consts = pcall(require, "consthelper")
local serializer_installed, serialization_helper = pcall(require, "serializationhelper")

local WIN = "aspd_editor_" .. GetPluginID()
local FONT = WIN .. "_font"
local HEADER_FONT = WIN .. "_header"

local show, hide, addStep, removeStep, editStep, saveSpeedwalk
local initialize, draw, drawWindow, drawToolbar, drawStepList
local onAddClick, onRemoveClick, onUpClick, onDownClick, onEditClick
local onStepClick, onAddMenuClick, onSaveClick, insertStep
local parseSpeedwalkToSteps, createSpeedwalkFromSteps, formatStepDisplay
local checkString, checkNumber, checkName, checkSmallNumber, splitTwo

local string_validator = { validate = checkString }
local small_number_validator = { validate = checkSmallNumber }
local number_validator = { validate = checkNumber }
local name_validator = { validate = checkName }

local STEP_TYPES = { EXECUTE = 1, MAPPER = 2, RUN = 3, DISTANCE = 4, SEARCH = 5,
                     UNLOCK = 6, KILL = 7, LOOT = 8, PEEK = 9, WAIT = 10, 
                     WAIT_PROMPT = 11, PAUSE = 12, CAST = 13, PLAN = 14 }

local speedwalk_name = ""
local steps = {}
local selected_step = nil
local list_scroll_offset = 0
local is_scroll_dragging = false
local scroll_drag_start_y = 0
local scroll_drag_start_offset = 0
local SCROLL_WIDTH = 12
local initialized = false

local POSITION = {}
local SIZES = {
  PADDING = 4,
  LINE_HEIGHT = 16,
  BUTTON_HEIGHT = 20,
  BUTTON_WIDTH = 70,
}

show = function(edit_speedwalk)
  if not initialized then
    initialize()
  end

  local speedwalks = serialization_helper.GetSerializedVariable("advanced_speedwalks", {})
  local speedwalk = speedwalks[edit_speedwalk]

  if speedwalk then
    steps = parseSpeedwalkToSteps(speedwalk)
    speedwalk_name = edit_speedwalk or ""
  else
    steps = {}
    speedwalk_name = ""
  end

  draw()
  WindowShow(WIN, true)
end

hide = function()
  if WindowInfo(WIN, 5) then
    WindowShow(WIN, false)
  end
end

initialize = function()
  if not initialized then
    local left = consts.GetOutputLeft() + 50
    local top = consts.GetOutputTop() + 50
    local right = consts.GetOutputRight() - 50
    local bottom = consts.GetOutputBottom() - 50

    POSITION.WIDTH = right - left
    POSITION.HEIGHT = bottom - top

    WindowCreate(WIN, left, top, POSITION.WIDTH, POSITION.HEIGHT, miniwin.pos_center_all, 0, 0)
    WindowSetZOrder(WIN, 5000)
    WindowFont(WIN, FONT, "Lucida Console", 9)
    WindowFont(WIN, HEADER_FONT, "Lucida Console", 10, true)
    
    SIZES.LINE_HEIGHT = WindowFontInfo(WIN, FONT, 1) - WindowFontInfo(WIN, FONT, 4) + 2
    SIZES.BUTTON_HEIGHT = SIZES.LINE_HEIGHT + 4
  end

  initialized = true
end

draw = function()
  WindowShow(WIN, false)

  drawWindow()
  drawToolbar()
  drawStepList()
  
  WindowShow(WIN, true)
end

drawWindow = function()
  WindowRectOp(WIN, miniwin.rect_fill, 0, 0, POSITION.WIDTH, POSITION.HEIGHT, 0x1a1a1a)
  
  for i = 1, consts.GetBorderWidth() do
    WindowRectOp(WIN, miniwin.rect_frame, i - 1, i - 1, POSITION.WIDTH - i + 1, POSITION.HEIGHT - i + 1, 0x808080)
  end
  
  local title = "Speedwalk Editor"
  if speedwalk_name ~= "" then
    title = title .. " - " .. speedwalk_name
  end

  WindowText(WIN, HEADER_FONT, title, SIZES.PADDING, SIZES.PADDING, 0, 0, 0xffffff)
end

drawToolbar = function()
  local y = SIZES.PADDING + SIZES.LINE_HEIGHT + SIZES.PADDING
  local x = SIZES.PADDING
  local button_spacing = 8

  local function  add_dual_state_button(is_first_state, x, y, color1, color2, text, text_color1, text_color2, hotspot_id, on_click_callback, tooltip, hotspot_on_second)
    if is_first_state then
      WindowRectOp(WIN, miniwin.rect_fill, x, y, x + SIZES.BUTTON_WIDTH, y + SIZES.BUTTON_HEIGHT, color1)
      WindowText(WIN, FONT, text, x + 4, y + 3, 0, 0, text_color1)
      WindowAddHotspot(WIN, hotspot_id, x, y, x + SIZES.BUTTON_WIDTH, y + SIZES.BUTTON_HEIGHT, "", "", "", "", on_click_callback, tooltip, 0)
    else
      WindowRectOp(WIN, miniwin.rect_fill, x, y, x + SIZES.BUTTON_WIDTH, y + SIZES.BUTTON_HEIGHT, color2)
      WindowText(WIN, FONT, text, x + 4, y + 3, 0, 0, text_color2)
      if hotspot_on_second then
        WindowAddHotspot(WIN, hotspot_id, x, y, x + SIZES.BUTTON_WIDTH, y + SIZES.BUTTON_HEIGHT, "", "", "", "", on_click_callback, tooltip, 0)
      end
    end
  end

  add_dual_state_button(true, x, y, 0x2d5a2d, 0x404040, "Add Step", 0x00ff00, 0xcccccc, "add_button", "speedwalk_onAddClick", "Add new step")
  x = x + SIZES.BUTTON_WIDTH + button_spacing
  add_dual_state_button(selected_step ~= nil, x, y, 0x5a2d2d, 0x404040, "Remove", 0xff6666, 0x808080, "remove_button", "speedwalk_onRemoveClick", "Remove selected step")
  x = x + SIZES.BUTTON_WIDTH + button_spacing
  add_dual_state_button(selected_step ~= nil and selected_step > 1, x, y, 0x2d4a5a, 0x404040, "Up", 0x66ccff, 0x808080, "up_button", "speedwalk_onUpClick", "Move step up")
  x = x + SIZES.BUTTON_WIDTH + button_spacing
  add_dual_state_button(selected_step ~= nil and selected_step < #steps, x, y, 0x2d4a5a, 0x404040, "Down", 0x66ccff, 0x808080, "down_button", "speedwalk_onDownClick", "Move step down")
  x = x + SIZES.BUTTON_WIDTH + button_spacing
  add_dual_state_button(#steps > 0, x, y, 0x2d5a4a, 0x404040, "Save", 0x00ff99, 0x808080, "save_button", "speedwalk_onSaveClick", "Save speedwalk")
  x = x + SIZES.BUTTON_WIDTH + button_spacing
  add_dual_state_button(true, x, y, 0x404040, 0x404040, "Cancel", 0xcccccc, 0xcccccc, "cancel_button", "speedwalk_onCancelClick", "Cancel")
end

drawStepList = function()
  local toolbar_height = SIZES.LINE_HEIGHT + SIZES.BUTTON_HEIGHT + SIZES.PADDING * 3
  local list_y = toolbar_height
  local list_bottom = POSITION.HEIGHT
  local x = SIZES.PADDING
  local list_width = POSITION.WIDTH - SIZES.PADDING * 2
  
  WindowText(WIN, FONT, "Steps:", x, list_y, 0, 0, 0xFFFFFF)
  list_y = list_y + SIZES.LINE_HEIGHT + 2
  
  WindowRectOp(WIN, miniwin.rect_fill, x, list_y, x + list_width, list_bottom - SIZES.PADDING, 0x0a0a0a)
  WindowRectOp(WIN, miniwin.rect_frame, x, list_y, x + list_width, list_bottom - SIZES.PADDING, 0x404040)
  WindowAddHotspot(WIN, "list_area", x, list_y, x + list_width, list_bottom - SIZES.PADDING, "", "", "speedwalk_onStepClick", "", "", "", miniwin.cursor_arrow, 0)
  WindowScrollwheelHandler(WIN, "list_area", "speedwalk_onWheel")
  
  local step_height = SIZES.BUTTON_HEIGHT + 2
  local available_height = (list_bottom - SIZES.PADDING) - (list_y + 4)
  local visible_count = math.max(0, math.floor(available_height / (step_height + 2)))
  local max_offset = math.max(0, #steps - visible_count)
  list_scroll_offset = math.max(0, math.min(list_scroll_offset, max_offset))

  local step_y = list_y + 4
  local start_idx = (list_scroll_offset or 0) + 1
  local end_idx = math.min(#steps, start_idx + visible_count - 1)
  for i = start_idx, end_idx do
    local step = steps[i]
    local is_selected = (i == selected_step)
    local bg_color = is_selected and 0x1a4a2a or 0x1a1a1a
    WindowRectOp(WIN, miniwin.rect_fill, x + 2, step_y, x + list_width - SCROLL_WIDTH - 4, step_y + step_height, bg_color)
    local step_text = formatStepDisplay(step, i)
    local text_color = is_selected and 0x00ff99 or 0xcccccc
    WindowText(WIN, FONT, step_text, x + 6, step_y + 4, 0, 0, text_color)
    step_y = step_y + step_height + 2
  end
  
  if #steps == 0 then
    WindowText(WIN, FONT, "(No steps - click 'Add Step' to begin)", x + 6, list_y + 20, 0, 0, 0x666666)
    return
  end

  local rail_left = x + list_width - SCROLL_WIDTH
  local rail_top = list_y + 4
  local rail_bottom = list_bottom - SIZES.PADDING
  WindowRectOp(WIN, miniwin.rect_fill, rail_left, rail_top, x + list_width - 2, rail_bottom, 0x202020)
  WindowRectOp(WIN, miniwin.rect_frame, rail_left, rail_top, x + list_width - 2, rail_bottom, 0x404040)

  if visible_count >= #steps then
    return
  end

  if #steps > 0 and visible_count > 0 then
    local rail_height = rail_bottom - rail_top
    local thumb_h = math.max(12, math.floor((visible_count / math.max(#steps, 1)) * rail_height))
    local thumb_max_top = rail_top + (rail_height - thumb_h)
    local thumb_top = rail_top
    if max_offset > 0 then
      thumb_top = rail_top + math.floor((list_scroll_offset / max_offset) * (rail_height - thumb_h))
    end
    local thumb_bottom = thumb_top + thumb_h
    WindowRectOp(WIN, miniwin.rect_fill, rail_left + 2, thumb_top, x + list_width - 4, thumb_bottom, 0x666666)
  end
end

function speedwalk_onWheel(flags, hotspot_id)
  local dir = -1
  if bit.band(flags, miniwin.wheel_scroll_back) ~= 0 then
    dir = 1
  end
  local toolbar_height = SIZES.LINE_HEIGHT + SIZES.BUTTON_HEIGHT + SIZES.PADDING * 3
  local list_y = toolbar_height
  local list_bottom = POSITION.HEIGHT
  local step_h = SIZES.BUTTON_HEIGHT + 2
  local available_height = (list_bottom - SIZES.PADDING) - (list_y + 4)
  local visible_count = math.floor(available_height / (step_h + 2))
  local total = #steps
  local max_offset = math.max(0, total - visible_count + 1)
  list_scroll_offset = math.max(0, math.min(max_offset, list_scroll_offset + (dir * 1)))
  draw()
end

formatStepDisplay = function(step, index)
  local prefix = string.format("[%2d] ", index)
  if step.type == STEP_TYPES.EXECUTE then
    return prefix .. "Execute: " .. (step.value or "???")
  elseif step.type == STEP_TYPES.MAPPER then
    return prefix .. "Mapper: goto room " .. (step.value or "???")
  elseif step.type == STEP_TYPES.RUN then
    return prefix .. "Run: run " .. (step.value or "???")
  elseif step.type == STEP_TYPES.DISTANCE then
    return prefix .. "Distance: run " .. (step.value or "???") .. " times"
  elseif step.type == STEP_TYPES.SEARCH then
    return prefix .. "Search: search " .. (step.value or "???")
  elseif step.type == STEP_TYPES.UNLOCK then
    return prefix .. "Unlock: cast 'magic unlock' " .. (step.value or "???")
  elseif step.type == STEP_TYPES.KILL then
    return prefix .. "Kill: kill" .. (step.value or "???")
  elseif step.type == STEP_TYPES.LOOT then
    local kill, item = splitTwo(step.value or "")
    return prefix .. "Loot: kill " .. (kill or "???") .. " and loot " .. (item or "???")
  elseif step.type == STEP_TYPES.PEEK then
    return prefix .. "Peek: look " .. (step.value or "???")
  elseif step.type == STEP_TYPES.WAIT then
    return prefix .. "Wait: wait for " .. (step.value or "???") .. " seconds"
  elseif step.type == STEP_TYPES.WAIT_PROMPT then
    return prefix .. "Wait Prompt: prompt " .. (step.value or "???")
  elseif step.type == STEP_TYPES.PAUSE then
    local reason = step.value or ""
    if reason == "" then reason = "default reason" end
    return prefix .. "Pause: ".. reason
  elseif step.type == STEP_TYPES.CAST then
    return prefix .. "Cast: cast '" .. (step.value or "???") .. "'"
  elseif step.type == STEP_TYPES.PLAN then
    return prefix .. "Plan: plan '" .. (step.value or "???") .. "'"
  end
  return prefix .. step.type .. ": " .. (step.value or "???")
end

function speedwalk_onAddClick(flags, hotspot_id)
  local addIdx = utils.choose("Select Step Type", "Add Step", {
    "Execute Command", "Mapper Step", "Run Step", "Distance Step", "Search Step",
    "Unlock Step", "Kill Step", "Loot Step", "Peek Step", "Wait Step", "Prompt Step",
    "Pause Step", "Cast Step", "Plan Step" })
    
  addStep(addIdx)   
  draw()
end

function speedwalk_onAddMenuClick(flags, hotspot_id)
  show_add_menu = false
  menu_open_time = nil
  addStep(hotspot_id:sub(10)) -- remove "add_menu_" prefix
  draw()
end

function speedwalk_onRemoveClick(flags, hotspot_id)
  if selected_step then
    removeStep(selected_step)
    draw()
  end
end

function speedwalk_onUpClick(flags, hotspot_id)
  if selected_step and selected_step > 1 then
    steps[selected_step], steps[selected_step - 1] = steps[selected_step - 1], steps[selected_step]
    selected_step = selected_step - 1
    draw()
  end
end

function speedwalk_onDownClick(flags, hotspot_id)
  if selected_step and selected_step < #steps then
    steps[selected_step], steps[selected_step + 1] = steps[selected_step + 1], steps[selected_step]
    selected_step = selected_step + 1
    draw()
  end
end

function speedwalk_onStepClick(flags, hotspot_id)
  local mx, my = WindowInfo(WIN, 14), WindowInfo(WIN, 15)
  local toolbar_height = SIZES.LINE_HEIGHT + SIZES.BUTTON_HEIGHT + SIZES.PADDING * 3
  local list_y = toolbar_height
  local list_bottom = POSITION.HEIGHT
  local step_h = SIZES.BUTTON_HEIGHT + 2
  local num = math.floor((my - (list_y + 4)) / (step_h + 2)) + (list_scroll_offset or 0)
  if selected_step == num then
    -- Double click to edit
    local new_value = editStep(steps[num].type, steps[num].value)
    if new_value then
      if steps[num].type == STEP_TYPES.EXECUTE and new_value:find(";") > 0 then
        local first = true
        for ex in new_value:gmatch("([^;]+)") do
          if first then
            steps[num].value = ex
            first = false
          else
            table.insert(steps, selected_step + 1, {
              type = STEP_TYPES.EXECUTE,
              value = ex
            })
            selected_step = selected_step + 1
          end
        end
      else
        steps[num].value = new_value
      end
    end
  else
    selected_step = num
  end
  draw()
end

function speedwalk_onSaveClick(flags, hotspot_id)
  if #steps > 0 then
    local speedwalks = serialization_helper.GetSerializedVariable("advanced_speedwalks", {})
    if Trim(speedwalk_name or "") == "" then
      while true do
        speedwalk_name = utils.inputbox("Enter a name for the speedwalk:", "Save Speedwalk", speedwalk_name, nil, nil, name_validator)
        if Trim(speedwalk_name or "") == "" then
          utils.msgbox("Speedwalk name cannot be empty.", "Invalid Name")
        elseif speedwalks[speedwalk_name] ~= nil then
          local overwrite = utils.msgbox("A speedwalk with this name already exists. Overwrite?", "Confirm Overwrite", "yesnocancel")
          if overwrite == "yes" then
            break
          elseif overwrite == "cancel" then
            return
          end
        else
          break
        end
      end
    end

    speedwalks[speedwalk_name] = createSpeedwalkFromSteps()
    serialization_helper.SaveSerializedVariable("advanced_speedwalks", speedwalks)
    Note("Speedwalk saved successfully. Use 'aspd " .. speedwalk_name .. "' to start it.")
    hide()
  end
end

function speedwalk_onCancelClick(flags, hotspot_id)
  hide()
end

addStep = function(step_type)
  if step_type then
    local value = editStep(step_type, "")
    if step_type == STEP_TYPES.EXECUTE and value:find(";") > 0 then
      for ex in value:gmatch("([^;]+)") do
        insertStep(step_type, ex)
      end
    else
      insertStep(step_type, value)
    end    
  end
end

insertStep = function(step_type, value)
  if not selected_step or selected_step <= 0 or selected_step > #steps then
      table.insert(steps, {
        type = step_type,
        value = value
      })
    else
      table.insert(steps, selected_step + 1, {
        type = step_type,
        value = value
      })
      selected_step = selected_step + 1
    end
end

removeStep = function(index)
  table.remove(steps, index)
  if selected_step == index then
    selected_step = (index > 1) and (index - 1) or nil
  elseif selected_step and selected_step > index then
    selected_step = selected_step - 1
  end
end

checkString = function(input)
  if input == nil or input == "" then
    return false
  end
  if string:find(input, "~", 1, true) then
    utils.msgbox("The '~' character is not allowed.", "Invalid Input")
    return false
  end
  return true
end

checkNumber = function(input)
  local num = tonumber(input)
  if num == nil then
    return false
  end
  return true
end

checkSmallNumber = function(input)
  local num = tonumber(input)
  if num == nil then
    return false
  end
  return num >= 0 and num <= 9
end

checkName = function(input)
  input = Trim(input or ""):lower()
  if input == "" or input == "new" or input == "cancel" or input == "pause" or input == "resume" then
    return false
  end
  return true
end

editStep = function(type, value)
  value = Trim(value or "")
  if type == STEP_TYPES.EXECUTE then
    local cmd_val = value
    local rep_val = ""
    if value:find("~") == 1 then
      cmd_val = value:sub(3, #value)
      rep_val = value:sub(2, 3)
    end
    local command = utils.inputbox("Enter command to execute (use ; to add multiple):", "Edit Execute Step", cmd_val, nil, nil, string_validator)
    if command and command ~= "" then
      if command:find(";") > 0 then
        return command
      end
      local rep = utils.inputbox("Enter the number of times it should repeat (optional, 0-9):", "Edit Execute Step", rep_val, nil, nil, small_number_validator)
      if rep and rep ~= "" and rep ~= "1" then
        return "~" .. rep .. command
      else
        return command
      end
    end

  elseif type == STEP_TYPES.MAPPER then
    local room = utils.inputbox("Enter room number to use:", "Edit Mapper Step", value, nil, nil, number_validator)
    if room then
      return room
    end
    
  elseif type == STEP_TYPES.RUN then
    local run_dir = utils.inputbox("Enter a direction or destination:", "Edit Run Step", value , nil, nil, string_validator)
    if run_dir then
      return run_dir
    end
    
  elseif type == STEP_TYPES.DISTANCE then
    local dir, amt = splitTwo(value)
    local dest = utils.inputbox("Enter a direction to start running:", "Edit Distance Step", dir, nil, nil, string_validator)
    if dest then
      local dist = utils.inputbox("Enter distance:", "Edit Distance Step", amt, nil, nil, number_validator)
      if dist then
        return dest .. " " .. dist
      end
    end
    
  elseif type == STEP_TYPES.SEARCH then
    local obj = utils.inputbox("Enter a direction or object to search:", "Edit Search Step", value , nil, nil, string_validator)
    if obj then
      if obj:find(" ") and obj:find("'") ~= 1 and obj:find("\"") ~= 1 then
        obj = "'" .. obj .. "'"
      end
      return obj 
    end   
    
  elseif type == STEP_TYPES.UNLOCK then
    local unlock_dir = utils.inputbox("Enter a direction to unlock:", "Edit Unlock Step", value , nil, nil, string_validator)
    if unlock_dir then 
      return unlock_dir
    end
    
  elseif type == STEP_TYPES.KILL then
    local mob = utils.inputbox("Enter the keyword of the mob to kill:", "Edit Kill Step", value , nil, nil, string_validator)
    if mob then
      if mob:find(" ") and mob:find("'") ~= 1 and mob:find("\"") ~= 1 then
        mob = "'" .. mob .. "'"
      end
      return mob
    end

  elseif type == STEP_TYPES.LOOT then
    local mob_val, item_val = splitTwo(value)
    local mob = utils.inputbox("Enter the keyword of the mob to kill:", "Edit Loot Step", mob_val , nil, nil, string_validator)
    if mob then
      if mob:find(" ") and mob:find("'") ~= 1 and mob:find("\"") ~= 1 then
        mob = "'" .. mob .. "'"
      end

      local item = utils.inputbox("Enter the exact name of the item you want to loot:", "Edit Loot Step", item_val , nil, nil, string_validator)
      if item then
        if item:find(" ") and item:find("'") ~= 1 and item:find("\"") ~= 1 then
          item = "'" .. item .. "'"
        end

        return mob .. " " .. item
      end
    end
    
  elseif type == STEP_TYPES.PEEK then
    local peek_dir = utils.inputbox("Enter a direction to look:", "Edit Peek Step", value , nil, nil, string_validator)
    if peek_dir then
      return peek_dir
    end
    
  elseif type == STEP_TYPES.WAIT then
    local wait_dur = utils.inputbox("Enter duration in seconds:", "Edit Wait Step", value, nil, nil, number_validator)
    if wait_dur then
      return wait_dur
    end
    
  elseif type == STEP_TYPES.WAIT_PROMPT then
    local prompt_msg = utils.inputbox("Enter a message to display:", "Edit Prompt Step", value , nil, nil, string_validator)
    if prompt_msg then
      return prompt_msg
    end
    
  elseif type == STEP_TYPES.PAUSE then
    local pause_msg = utils.inputbox("Enter a message to display:", "Edit Pause Step", value , nil, nil, string_validator)
    if pause_msg then
      return pause_msg
    end
    
  elseif type == STEP_TYPES.CAST then
    local spell = utils.inputbox("Enter the name of the spell to cast:", "Edit Cast Step", value , nil, nil, string_validator)
    if spell and Trim(spell) ~= "" then
      return Trim(spell)
    end

  elseif type == STEP_TYPES.PLAN then
    local plan = utils.inputbox("Enter the name of the skill to plan:", "Edit Plan Step", value , nil, nil, string_validator)
    if plan and Trim(plan) ~= "" then
      return Trim(plan)
    end
  end

  return value
end

parseSpeedwalkToSteps = function(speedwalk)
  local result = {}
  for i, step in ipairs(speedwalk or {}) do
    local entry = {}
    local value = step
    if step:sub(1,2) == "~m" then
      entry.type = STEP_TYPES.MAPPER
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~r" then
      entry.type = STEP_TYPES.RUN
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~d" then
      entry.type = STEP_TYPES.DISTANCE
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~s" then
      entry.type = STEP_TYPES.SEARCH
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~u" then
      entry.type = STEP_TYPES.UNLOCK
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~k" then
      entry.type = STEP_TYPES.KILL
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~l" then
      entry.type = STEP_TYPES.LOOT
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~p" then
      entry.type = STEP_TYPES.PEEK
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~w" then
      entry.type = STEP_TYPES.WAIT
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~x" then
      entry.type = STEP_TYPES.WAIT_PROMPT
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~z" then
      entry.type = STEP_TYPES.PAUSE
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~c" then
      entry.type = STEP_TYPES.CAST
      entry.value = step:sub(3)
    elseif step:sub(1,2) == "~n" then
      entry.type = STEP_TYPES.PLAN
      entry.value = step:sub(3)
    else
      entry.type = STEP_TYPES.EXECUTE
      entry.value = step
    end
    table.insert(result, entry)
  end
  return result  
end

createSpeedwalkFromSteps = function()
  local result = {}
  for i, step in ipairs(steps) do
    if step.type == STEP_TYPES.EXECUTE then
      table.insert(result, step.value)
    elseif step.type == STEP_TYPES.MAPPER then
      table.insert(result, "~m" .. step.value)
    elseif step.type == STEP_TYPES.RUN then
      table.insert(result, "~r" .. step.value)
    elseif step.type == STEP_TYPES.DISTANCE then
      table.insert(result, "~d" .. step.value)
    elseif step.type == STEP_TYPES.SEARCH then
      table.insert(result, "~s" .. step.value)
    elseif step.type == STEP_TYPES.UNLOCK then
      table.insert(result, "~u" .. step.value)
    elseif step.type == STEP_TYPES.KILL then
      table.insert(result, "~k" .. step.value)
    elseif step.type == STEP_TYPES.LOOT then
      table.insert(result, "~l" .. step.value)
    elseif step.type == STEP_TYPES.PEEK then
      table.insert(result, "~p" .. step.value)
    elseif step.type == STEP_TYPES.WAIT then
      table.insert(result, "~w" .. step.value)
    elseif step.type == STEP_TYPES.WAIT_PROMPT then
      table.insert(result, "~x" .. step.value)
    elseif step.type == STEP_TYPES.PAUSE then
      table.insert(result, "~z" .. step.value)
    elseif step.type == STEP_TYPES.CAST then
      table.insert(result, "~c" .. step.value)
    elseif step.type == STEP_TYPES.PLAN then
      table.insert(result, "~n" .. step.value)
    end
  end
  return result
end

splitTwo = function(input)
  local parts = {}
  local i = 1
  local len = #input

  local function skipSpaces()
    while i <= len and input:sub(i,i):match("%s") do
      i = i + 1
    end
  end

  local function parseQuoted(quote)
    i = i + 1
    local start = i
    local out = {}

    while i <= len do
      local c = input:sub(i,i)
      if c == "\\" and i < len then
        table.insert(out, input:sub(i+1,i+1))
        i = i + 2
      elseif c == quote then
        i = i + 1
        break
      else
        table.insert(out, c)
        i = i + 1
      end
    end

    return table.concat(out)
  end

  local function parseWord()
    local start = i
    while i <= len and not input:sub(i,i):match("%s") do
      i = i + 1
    end
    return input:sub(start, i-1)
  end

  skipSpaces()

  if i <= len then
    local c = input:sub(i,i)
    if c == '"' or c == "'" then
      parts[1] = parseQuoted(c)
    else
      parts[1] = parseWord()
    end
  end

  skipSpaces()

  if i <= len then
    local c = input:sub(i,i)
    if c == '"' or c == "'" then
      parts[2] = parseQuoted(c)
    else
      parts[2] = input:sub(i):match("^%s*(.-)%s*$")
    end
  end

  return parts[1], parts[2]
end

return {
  show = show,
  hide = hide
}
