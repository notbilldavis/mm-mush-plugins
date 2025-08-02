local CONFIG_WINDOW = require "configuration_miniwindow"
local WIN = GetPluginID()
local INFOFONT = WIN .. "_info_font"
local CONFIG = nil
local LINE_HEIGHT = nil
local BORDER_WIDTH = 3
local COORD_X = -1
local COORD_Y = -1
local ZOOM_LEVEL = {}
local CURRENT_PLANE = "alyria"

local MM_PATH = GetPluginInfo(GetPluginID(), 20):gsub("\\", "/") .. "/WorldMap/"
local LOCATION_ICON_PATH = MM_PATH .. "location.png"
local TILE_CACHE = {}
local CACHE_ORDER = {}
local SCROLL_TIMER = nil
local LOCATION_ICON = nil

local PLANE_DETAILS = { 
  alyria = { x = 2299, y = 1499, z = 4, l = true, ox = 0, oy = 0 },
  underground = { x = 2299, y = 1499, z = 4, l = true, ox = 0, oy = 0 },
  sigil = { x = 2299, y = 1499, z = 4, l = true, ox = 0, oy = 0 },
  faerie = { x = 613, y = 400, z = 2, l = false, ox = 0, oy = 0 },
  lasler = { x = 155, y = 101, z = 0, l = false, ox = 0, oy = 0 },
  verity = { x = 144, y = 94, z = 0, l = false, ox = 0, oy = 0 },
  social = { x = 144, y = 94, z = 0, l = false, ox = 0, oy = 125 }
}

local PLANE_MAP = {
    ["Alyria"] = "alyria",
    ["Alyrian Underworld"] = "underground",
    ["Faerie Plane"] = "faerie",
    ["IEN Ivory Tower"] = "social",
    ["Lasler Wilderness"] = "lasler",
    ["Sigil Underground"] = "sigil",
    ["Verity Isle"] = "verity",
  }

function InitializeMiniWindow()
  loadLocationIcon()
  loadSavedData()
  createWindowAndFont()
  drawMiniWindow()
end

function SetCoords(serialized_room_info)
  local room_info = Deserialize(serialized_room_info)
  local x, y, plane = room_info.coord.x, room_info.coord.y, room_info.coord.name
  plane = PLANE_MAP[plane]
  if COORD_X ~= x or COORD_Y ~= y or CURRENT_PLANE ~= plane then
    COORD_X = x
    COORD_Y = y
    CURRENT_PLANE = plane
    drawMiniWindow()
  end

  if CONFIG.HIDE_WILDS then
    if room_info.coord.code ~= nil then
      HideWindow()
    else
      ShowWindow()
    end
  end
end

function ShowWindow()
  WindowShow(WIN, true)
end

function HideWindow()
  CONFIG_WINDOW.Hide()
  WindowShow(WIN, false)
end

function loadLocationIcon()
  local f = assert(io.open(LOCATION_ICON_PATH, "rb"))
  local img = f:read("*a")
  f:close()
  LOCATION_ICON = img
end

function loadSavedData()
  local serialized_config = GetVariable("worldmap_config") or ""
  if serialized_config == "" then
    CONFIG = {}
  else
    CONFIG = Deserialize(serialized_config)
  end

  CONFIG.FONT = getValueOrDefault(CONFIG.BUTTON_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BORDER_COLOR = getValueOrDefault(CONFIG.BORDER_COLOR, 12632256)
  CONFIG.WINDOW_LEFT = getValueOrDefault(CONFIG.WINDOW_LEFT, GetInfo(274) + GetInfo(276) + GetInfo(277))
  CONFIG.WINDOW_TOP = getValueOrDefault(CONFIG.WINDOW_TOP, GetInfo(273) + GetInfo(276) + GetInfo(277))
  CONFIG.WINDOW_WIDTH = getValueOrDefault(CONFIG.WINDOW_WIDTH, 500)
  CONFIG.WINDOW_HEIGHT = getValueOrDefault(CONFIG.WINDOW_HEIGHT, 750 * (CONFIG.WINDOW_WIDTH / 1150))
  CONFIG.MAX_CACHE_SIZE = getValueOrDefault(CONFIG.MAX_CACHE_SIZE, 16)
  CONFIG.HIDE_WILDS = getValueOrDefault(CONFIG.HIDE_WILDS, true)

  local serialized_zoom_level = GetVariable("worldmap_zoom") or ""
  if serialized_zoom_level == "" then
    ZOOM_LEVEL = {}
  else
    ZOOM_LEVEL = Deserialize(serialized_zoom_level)
  end

  ZOOM_LEVEL.alyria = getValueOrDefault(ZOOM_LEVEL.alyria, 0)
  ZOOM_LEVEL.underground = getValueOrDefault(ZOOM_LEVEL.underground, 0)
  ZOOM_LEVEL.sigil = getValueOrDefault(ZOOM_LEVEL.sigil, 0)
  ZOOM_LEVEL.faerie = getValueOrDefault(ZOOM_LEVEL.faerie, 0)
  ZOOM_LEVEL.lasler = getValueOrDefault(ZOOM_LEVEL.lasler, 0)
  ZOOM_LEVEL.verity = getValueOrDefault(ZOOM_LEVEL.verity, 0)
  ZOOM_LEVEL.social = getValueOrDefault(ZOOM_LEVEL.social, 0)
end

function createWindowAndFont()
  if CONFIG == nil then return end

  local font = CONFIG["FONT"]
  
  WindowCreate(WIN, 0, 0, 0, 0, 0, 0, 0)
  
  WindowFont(WIN, INFOFONT, font.name, font.size,
    convertToBool(font.bold), 
    convertToBool(font.italic), 
    convertToBool(font.underline), 
    convertToBool(font.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, INFOFONT, 1) - WindowFontInfo(WIN, INFOFONT, 4) + 2
  BORDER_WIDTH = GetInfo(277)

  CONFIG.WINDOW_LEFT = GetInfo(274) + GetInfo(276) + GetInfo(277) + 1
  CONFIG.WINDOW_TOP = 0
  CONFIG.WINDOW_WIDTH = GetInfo(281) - GetInfo(274) + GetInfo(276) + GetInfo(277)
  CONFIG.WINDOW_HEIGHT = 750 * (CONFIG.WINDOW_WIDTH / 1150)
  
  WindowPosition(WIN, CONFIG.WINDOW_LEFT, CONFIG.WINDOW_TOP, 4, 2)
  WindowResize(WIN, CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT, 0)

  saveMiniWindow()
end

function drawMiniWindow()
  if CONFIG ~= nil and COORD_X ~= nil and COORD_Y ~= nil then
    WindowShow(WIN, false)

    if CURRENT_PLANE == nil then 
      Note("Unknown plane!")
      return
    end

    local width, height = WindowInfo(WIN, 3), WindowInfo(WIN, 4)
    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, width, height, 0)

    local num_of_tiles = (2^ZOOM_LEVEL[CURRENT_PLANE])
    local max_x = 1150 * num_of_tiles
    local max_y = 750 * num_of_tiles
    local scaled_x = COORD_X / PLANE_DETAILS[CURRENT_PLANE].x * max_x
    local scaled_y = COORD_Y / PLANE_DETAILS[CURRENT_PLANE].y * max_y
    local tile_x = math.floor(scaled_x / 1150)
    local tile_y = math.floor(scaled_y / 750)
    local local_x = scaled_x % 1150
    local local_y = scaled_y % 750
    local offset_x = local_x - width / 2
    local offset_y = local_y - height / 2
    local debug_boxes = {}

    offset_x = offset_x + 4
    
    table.insert(debug_boxes, drawTile(tile_x, tile_y, offset_x, offset_y, "main", 32768))

    if PLANE_DETAILS[CURRENT_PLANE].l then
      if offset_x > 0 then table.insert(debug_boxes, drawTile(tile_x + 1, tile_y, offset_x - 1150, offset_y, "left", 255)) end
      if offset_x < 0 then table.insert(debug_boxes, drawTile(tile_x - 1, tile_y, offset_x + 1150, offset_y, "right", 255)) end
      if offset_y > 0 then table.insert(debug_boxes, drawTile(tile_x, tile_y + 1, offset_x, offset_y - 750, "up", ColourNameToRGB("blue"))) end
      if offset_y < 0 then table.insert(debug_boxes, drawTile(tile_x, tile_y - 1, offset_x, offset_y + 750, "down", ColourNameToRGB("blue"))) end
        
      if offset_x > 0 and offset_y > 0 then table.insert(debug_boxes, drawTile(tile_x + 1, tile_y + 1, offset_x - 1150, offset_y - 750, "left-up", ColourNameToRGB("yellow"))) end
      if offset_x < 0 and offset_y < 0 then table.insert(debug_boxes, drawTile(tile_x - 1, tile_y - 1, offset_x + 1150, offset_y + 750, "right-down", ColourNameToRGB("cyan"))) end
      if offset_x > 0 and offset_y < 0 then table.insert(debug_boxes, drawTile(tile_x + 1, tile_y - 1, offset_x - 1150, offset_y + 750, "left-down", ColourNameToRGB("yellow"))) end
      if offset_x < 0 and offset_y > 0 then table.insert(debug_boxes, drawTile(tile_x - 1, tile_y + 1, offset_x + 1150, offset_y - 750, "right-up", ColourNameToRGB("cyan"))) end
    end
    
    for i = 0, BORDER_WIDTH - 1 do
      WindowRectOp(WIN, miniwin.rect_frame, 0 + i, 0 + i, width - i, height - i, CONFIG.BORDER_COLOR)
    end

    -- for _, box in ipairs(debug_boxes) do
    --   for i = 0, BORDER_WIDTH - 1 do
    --     WindowRectOp(WIN, miniwin.rect_frame, box.left + i, box.top + i, box.right - i, box.bottom - i, box.color)
    --   end
    -- end

    WindowLoadImageMemory(WIN, "location_icon", LOCATION_ICON)

    local icon_point_x = WindowImageInfo(WIN, "location_icon", 2) * -1/2
    local icon_point_y = WindowImageInfo(WIN, "location_icon", 3) * -1
    WindowDrawImageAlpha(WIN, "location_icon", width / 2 + icon_point_x, height / 2 + icon_point_y, 0, 0, .8)

    WindowAddHotspot(WIN, "world_map_hotspot", BORDER_WIDTH, BORDER_WIDTH, width - BORDER_WIDTH, height - BORDER_WIDTH, "", "", "", "", "OnMouseUp", "", miniwin.cursor_arrow, 0)  
    WindowScrollwheelHandler(WIN, "world_map_hotspot", "OnWheel")  
    
    WindowSetZOrder(WIN, 9999)
    
    WindowShow(WIN, true)
  end
end

function drawTile(tile_x, tile_y, offset_x, offset_y, debug, color)
  --if debug then Note(debug) end

  local tile = getMapTile(tile_x % (2^ZOOM_LEVEL[CURRENT_PLANE]), tile_y % (2^ZOOM_LEVEL[CURRENT_PLANE]))

  WindowDrawImage(WIN, tile, 
    BORDER_WIDTH - offset_x - PLANE_DETAILS[CURRENT_PLANE].ox, 
    BORDER_WIDTH - offset_y - PLANE_DETAILS[CURRENT_PLANE].oy, 
    1150 + BORDER_WIDTH - offset_x - PLANE_DETAILS[CURRENT_PLANE].ox, 
    750 + BORDER_WIDTH - offset_y - PLANE_DETAILS[CURRENT_PLANE].oy, 
    miniwin.image_stretch)

  return { 
    left = BORDER_WIDTH - offset_x - PLANE_DETAILS[CURRENT_PLANE].ox, 
    top = BORDER_WIDTH - offset_y - PLANE_DETAILS[CURRENT_PLANE].oy, 
    right = 1150 + BORDER_WIDTH - offset_x - PLANE_DETAILS[CURRENT_PLANE].ox, 
    bottom = 750 + BORDER_WIDTH - offset_y - PLANE_DETAILS[CURRENT_PLANE].oy,
    color = color
  }
end

function getMapTile(x, y)
  local filename = string.format("x%03dy%03d.png", x, y)
  local filepath = MM_PATH .. CURRENT_PLANE .. "/" .. ZOOM_LEVEL[CURRENT_PLANE] .. "/" .. filename

  --Note(filepath)

  if TILE_CACHE[filepath] then
    for i, name in ipairs(CACHE_ORDER) do
      if name == filepath then
        table.remove(CACHE_ORDER, i)
        break
      end
    end
    table.insert(CACHE_ORDER, filepath)
    return TILE_CACHE[filepath]
  end

  local ok = WindowLoadImage(WIN, filepath, filepath)
  if not ok then return nil end

  TILE_CACHE[filepath] = filepath
  table.insert(CACHE_ORDER, filepath)

  if #CACHE_ORDER > CONFIG.MAX_CACHE_SIZE then
    local evict = table.remove(CACHE_ORDER, 1)
    TILE_CACHE[evict] = nil
  end

  return filepath
end

function OnMouseUp(flags, hotspot_id)
  if flags == miniwin.hotspot_got_rh_mouse then
    local result = WindowMenu(WIN, WindowInfo(WIN, 14),  WindowInfo(WIN, 15), "configure")
    if result == "configure" then
      configure()
    end
  end
end

function OnWheel(flags, hotspot_id)
  if bit.band(flags, miniwin.wheel_scroll_back) ~= 0 then
    if ZOOM_LEVEL[CURRENT_PLANE] == 0 then return end
    ZOOM_LEVEL[CURRENT_PLANE] = math.max(ZOOM_LEVEL[CURRENT_PLANE] - 1, 0)
  else
    if ZOOM_LEVEL[CURRENT_PLANE] == PLANE_DETAILS[CURRENT_PLANE].z then return end
    ZOOM_LEVEL[CURRENT_PLANE] = math.min(ZOOM_LEVEL[CURRENT_PLANE] + 1, PLANE_DETAILS[CURRENT_PLANE].z)
  end

  SetVariable("worldmap_zoom", Serialize(ZOOM_LEVEL))
  SaveState()

  drawMiniWindow()
end

function saveMiniWindow()
  local sticky_options = { 
    left = WindowInfo(WIN, 10), top = WindowInfo(WIN, 11), 
    width = WindowInfo(WIN, 3), height = WindowInfo(WIN, 4), 
    border = CONFIG.BORDER_COLOR,
  }

  SetVariable("worldmap_config", Serialize(CONFIG))
  SetVariable("worldmap_zoom", Serialize(ZOOM_LEVEL))
  SaveState()
end

function configure()
  local config = {
    Map = {
      --FONT = { type = "font", value = CONFIG.FONT.name .. " (" .. CONFIG.FONT.size .. ")", raw_value = CONFIG.FONT },
      BORDER_COLOR = { sort = 1, type = "color", raw_value = CONFIG.BORDER_COLOR },
      HIDE_WILDS = { sort = 2, label = "Hide When Inside", type = "bool", raw_value = CONFIG.HIDE_WILDS },
      MAX_CACHE_SIZE = { sort = 3, type = "number", raw_value = CONFIG.MAX_CACHE_SIZE, min = 0, max = 200 },
    },
    Position = {
      WINDOW_LEFT = { sort = 1, type = "number", raw_value = CONFIG.WINDOW_LEFT, min = 0, max = GetInfo(281) - 50 },
      WINDOW_TOP = { sort = 2, type = "number", raw_value = CONFIG.WINDOW_TOP, min = 0, max = GetInfo(280) - 50 },
      WINDOW_WIDTH = { sort = 3, type = "number", raw_value = CONFIG.WINDOW_WIDTH, min = 50, max = GetInfo(281) },
      --WINDOW_HEIGHT = { sort = 4, type = "number", raw_value = CONFIG.WINDOW_HEIGHT, min = 50, max = GetInfo(280) },
    }
  }
  
  CONFIG_WINDOW.Show(config, configureDone)
end

function configureDone(group_id, option_id, config)
  CONFIG[option_id] = config.raw_value

  if option_id == "WINDOW_WIDTH" then
    CONFIG.WINDOW_HEIGHT = 750 * (CONFIG.WINDOW_WIDTH / 1150)
  end
  
  saveMiniWindow()
  createWindowAndFont()
  drawMiniWindow()
end

function getValueOrDefault(value, default)
  if value == nil then
    return default
  end

  return value
end

function convertToBool(bool_value, def_value)
  if bool_value == 0 or bool_value == "0" then
    return false
  elseif bool_value == 1 or bool_value == "1" then
    return true
  end

  return def_value
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