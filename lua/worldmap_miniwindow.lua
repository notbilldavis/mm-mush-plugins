local serializer_installed, serialization_helper = pcall(require, "serializationhelper")
local config_installed, config_window = pcall(require, "configuration_miniwindow")
local const_installed, consts = pcall(require, "consthelper")

local WIN = GetPluginID()
local INFOFONT = WIN .. "_info_font"

local initialize, setCoords, setCrystalCoords, setDestinationCoords
local drawMiniWindow, showWindow, hideWindow, loadIcons, loadSavedData, createWindowAndFont,
  isAutoUpdateEnabled, loadIcon, getDefaultOffsets, saveMiniWindow, drawTile, getMapTile,
  drawDebugLabel, tryShowCrystalMarker, tryShowDestinationMarkers, configure, configureDone

local CONFIG = nil
local LINE_HEIGHT = nil
local ICON_CACHE = {}
local TILE_CACHE = {}
local CACHE_ORDER = {}

local IS_RESIZING = false
local IS_DRAGGING = false
local RESIZE_DRAG_X = nil
local RESIZE_DRAG_Y = nil
local START_DRAG_Y = 0
local START_DRAG_OFFSET = 0

local COORD_X = nil
local COORD_Y = nil
local ZOOM_LEVEL = {}
local CURRENT_PLANE = "alyria"
local MARKERS = {
  crystal = nil,
  one = nil,
  two = nil,
  three = nil,
}

local PLANE_DETAILS = { 
  alyria = { x = 2299, y = 1499, z = 4, l = true },
  underground = { x = 2299, y = 1499, z = 4, l = true },
  sigil = { x = 2299, y = 1499, z = 4, l = true },
  faerie = { x = 613, y = 400, z = 2, l = false },
  lasler = { x = 155, y = 101, z = 0, l = false },
  verity = { x = 144, y = 94, z = 0, l = false },
  social = { x = 144, y = 94, z = 0, l = false }
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

initialize = function()
  loadSavedData()
  loadIcons()
  createWindowAndFont()
  drawMiniWindow()
end

setCoords = function(serialized_room_info)
  local room_info = serialization_helper.Deserialize(serialized_room_info)
  local x, y, plane = room_info.coord.x, room_info.coord.y, room_info.coord.name
  plane = PLANE_MAP[plane]
  if COORD_X ~= x or COORD_Y ~= y or CURRENT_PLANE ~= plane then
    COORD_X = x
    COORD_Y = y
    CURRENT_PLANE = plane
    drawMiniWindow()
  end

  if CONFIG.HIDE_WILDS then
    if room_info.coord.code == nil then
      hideWindow()
    else
      showWindow()
    end
  end
end

setCrystalCoords = function(x, y)
  MARKERS.crystal = { x = x, y = y }
  drawMiniWindow()
end

setDestinationCoords = function(i, x, y)
  if i == 1 then
    MARKERS.one = { x = x, y = y }
  elseif i == 2 then
    MARKERS.two = { x = x, y = y }
  elseif i == 3 then
    MARKERS.three = { x = x, y = y }
  end
  drawMiniWindow()
end

isAutoUpdateEnabled = function()
  if CONFIG == nil then return false end
  return CONFIG.AUTOUPDATE or false
end

showWindow = function()
  WindowShow(WIN, true)
end

hideWindow = function()
  config_window.Hide()
  WindowShow(WIN, false)
end

loadIcons = function()
  ICON_CACHE.location = loadIcon(CONFIG.IMAGES_PATH .. "location.png")
  ICON_CACHE.crystal = loadIcon(CONFIG.IMAGES_PATH .. "crystal.png")
  ICON_CACHE.one = loadIcon(CONFIG.IMAGES_PATH .. "one.png")
  ICON_CACHE.two = loadIcon(CONFIG.IMAGES_PATH .. "two.png")
  ICON_CACHE.three = loadIcon(CONFIG.IMAGES_PATH .. "three.png")
end

loadIcon = function(icon_path)
  local f = assert(io.open(icon_path, "rb"))
  local img = f:read("*a")
  f:close()
  return img
end

loadSavedData = function()
  CONFIG = serialization_helper.GetSerializedVariable("worldmap_config")
  
  CONFIG.FONT = serialization_helper.GetValueOrDefault(CONFIG.BUTTON_FONT, { name = "Lucida Console", size = 9, colour = 16777215, bold = 0, italic = 0, underline = 0, strikeout = 0 })
  CONFIG.BORDER_COLOR = serialization_helper.GetValueOrDefault(CONFIG.BORDER_COLOR, 12632256)
  CONFIG.WINDOW_LEFT = serialization_helper.GetValueOrDefault(CONFIG.WINDOW_LEFT, GetInfo(274) + GetInfo(276) + GetInfo(277))
  CONFIG.WINDOW_TOP = serialization_helper.GetValueOrDefault(CONFIG.WINDOW_TOP, GetInfo(273) + GetInfo(276) + GetInfo(277))
  CONFIG.WINDOW_WIDTH = serialization_helper.GetValueOrDefault(math.max(CONFIG.WINDOW_WIDTH, 100), 500)
  CONFIG.WINDOW_HEIGHT = serialization_helper.GetValueOrDefault(CONFIG.WINDOW_HEIGHT, 750 * (CONFIG.WINDOW_WIDTH / 1150))
  CONFIG.MAX_CACHE_SIZE = serialization_helper.GetValueOrDefault(CONFIG.MAX_CACHE_SIZE, 16)
  CONFIG.HIDE_WILDS = serialization_helper.GetValueOrDefault(CONFIG.HIDE_WILDS, true)
  CONFIG.OFFSETS = serialization_helper.GetValueOrDefault(CONFIG.OFFSETS, getDefaultOffsets())
  CONFIG.AUTOUPDATE = serialization_helper.GetValueOrDefault(CONFIG.AUTUPDATE, true)
  CONFIG.CIRCLE = serialization_helper.GetValueOrDefault(CONFIG.CIRCLE, false)
  CONFIG.OPACITY = serialization_helper.GetValueOrDefault(CONFIG.OPACITY, 80)
  CONFIG.STRETCH = serialization_helper.GetValueOrDefault(CONFIG.STRETCH, true)
  CONFIG.DRAW_DEBUG = serialization_helper.GetValueOrDefault(CONFIG.DRAW_DEBUG, false)
  CONFIG.IMAGES_PATH = serialization_helper.GetValueOrDefault(CONFIG.IMAGES_PATH, GetPluginInfo(GetPluginID(), 20):gsub("\\", "/") .. "/WorldMap/")
  
  ZOOM_LEVEL = serialization_helper.GetSerializedVariable("worldmap_zoom")

  ZOOM_LEVEL.alyria = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.alyria, 0)
  ZOOM_LEVEL.underground = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.underground, 0)
  ZOOM_LEVEL.sigil = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.sigil, 0)
  ZOOM_LEVEL.faerie = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.faerie, 0)
  ZOOM_LEVEL.lasler = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.lasler, 0)
  ZOOM_LEVEL.verity = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.verity, 0)
  ZOOM_LEVEL.social = serialization_helper.GetValueOrDefault(ZOOM_LEVEL.social, 0)
end

getDefaultOffsets = function()
  local planes = { 
    alyria = {}, underground = {}, sigil = {}, faerie = {}, lasler = {}, verity = {}, social = {}
  }

  for plane, details in pairs(PLANE_DETAILS) do
    for i = 1, details.z + 1 do
      planes[plane][i] = { x = 0, y = 0 }
    end
  end  

  planes.alyria[1]={y=0,x=0,}
  planes.alyria[2]={y=1,x=2,}
  planes.alyria[3]={y=1,x=2,}
  planes.alyria[4]={y=1,x=3,}
  planes.alyria[5]={y=2,x=4,}
  planes.underground[1]={y=3,x=3,}
  planes.underground[2]={y=4,x=3,}
  planes.underground[3]={y=5,x=3,}  
  planes.underground[4]={y=7,x=3,}
  planes.underground[5]={y=10,x=2,}
  planes.sigil[1]={y=1,x=3,}
  planes.sigil[2]={y=0,x=2,}
  planes.sigil[3]={y=4,x=1,}
  planes.sigil[4]={y=0,x=-1,}
  planes.sigil[5]={y=0,x=-5,}
  planes.faerie[1]={y=8,x=4,}
  planes.faerie[2]={y=10,x=3,}
  planes.faerie[3]={y=15,x=3,}
  
  return planes
end

createWindowAndFont = function()
  if CONFIG == nil then return end

  local font = CONFIG["FONT"]
  local flags = 2

  if CONFIG.CIRCLE then 
    flags = 6 
  end

  WindowCreate(WIN, CONFIG.WINDOW_LEFT, CONFIG.WINDOW_TOP, CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT, 0, flags, 11766186)
  
  WindowFont(WIN, INFOFONT, font.name, font.size,
    serialization_helper.ConvertToBool(font.bold), 
    serialization_helper.ConvertToBool(font.italic), 
    serialization_helper.ConvertToBool(font.underline), 
    serialization_helper.ConvertToBool(font.strikeout))

  LINE_HEIGHT = WindowFontInfo(WIN, INFOFONT, 1) - WindowFontInfo(WIN, INFOFONT, 4) + 2
 
  saveMiniWindow()
end

drawMiniWindow = function()
  if CONFIG ~= nil and COORD_X ~= nil and COORD_Y ~= nil then
    WindowShow(WIN, false)

    WindowRectOp(WIN, miniwin.rect_fill, 0, 0, 0, 0, ColourNameToRGB("black"))

    if CURRENT_PLANE == nil then 
      return
    end

    local printable_area = { x = (CONFIG.WINDOW_WIDTH - consts.GetBorderWidth() * 2), y = (CONFIG.WINDOW_HEIGHT - consts.GetBorderWidth() * 2) }

    local width, height = printable_area.x, printable_area.y --WindowInfo(WIN, 3), WindowInfo(WIN, 4)
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

    offset_x = -1 * (offset_x + CONFIG.OFFSETS[CURRENT_PLANE][ZOOM_LEVEL[CURRENT_PLANE] + 1].x + consts.GetBorderWidth())
    offset_y = -1 * (offset_y + CONFIG.OFFSETS[CURRENT_PLANE][ZOOM_LEVEL[CURRENT_PLANE] + 1].y + consts.GetBorderWidth())
    
    local window_name = WIN
    if CONFIG.CIRCLE then
      window_name = WIN .. "_mask"
      WindowCreate(window_name, 0, 0, 0, 0, 0, 2, 0)
      WindowResize(window_name, CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT, 0)
      WindowRectOp(window_name, 2, 0, 0, 0, 0, ColourNameToRGB("white"))
      WindowImageFromWindow(window_name, "alpha", window_name)
    end    

    table.insert(debug_boxes, drawTile(window_name, tile_x, tile_y, offset_x, offset_y, "main", 32768))  
    table.insert(debug_boxes, drawTile(window_name, tile_x + 1, tile_y, offset_x + 1150, offset_y, "right", ColourNameToRGB("red")))
    table.insert(debug_boxes, drawTile(window_name, tile_x - 1, tile_y, offset_x - 1151, offset_y, "left", ColourNameToRGB("tomato")))
    table.insert(debug_boxes, drawTile(window_name, tile_x, tile_y + 1, offset_x, offset_y + 750, "down", ColourNameToRGB("blue")))
    table.insert(debug_boxes, drawTile(window_name, tile_x, tile_y - 1, offset_x, offset_y - 751, "up", ColourNameToRGB("deepskyblue")))      
    table.insert(debug_boxes, drawTile(window_name, tile_x + 1, tile_y + 1, offset_x + 1150, offset_y + 750, "right-down", ColourNameToRGB("yellow")))
    table.insert(debug_boxes, drawTile(window_name, tile_x - 1, tile_y - 1, offset_x - 1151, offset_y - 751, "left-up", ColourNameToRGB("cyan")))
    table.insert(debug_boxes, drawTile(window_name, tile_x + 1, tile_y - 1, offset_x + 1150, offset_y - 751, "right-up", ColourNameToRGB("orange")))
    table.insert(debug_boxes, drawTile(window_name, tile_x - 1, tile_y + 1, offset_x - 1151, offset_y + 750, "left-down", ColourNameToRGB("purple")))
    
    if CONFIG.DRAW_DEBUG then
      for _, box in ipairs(debug_boxes) do
        if box ~= nil then
          for i = 0, consts.GetBorderWidth() - 1 do
            WindowRectOp(WIN, miniwin.rect_frame, box.left + i, box.top + i, box.right - i, box.bottom - i, box.color)
          end

          drawDebugLabel(box)
        end
      end
    end

    -- TODO: these marks don't show on map wrapping
    tryShowCrystalMarker(window_name, max_x, max_y, scaled_x, scaled_y)
    tryShowDestinationMarkers(window_name, max_x, max_y, scaled_x, scaled_y)

    WindowLoadImageMemory(window_name, "location_icon", ICON_CACHE.location)
    local icon_point_x = WindowImageInfo(window_name, "location_icon", 2) * -1/2
    local icon_point_y = WindowImageInfo(window_name, "location_icon", 3) * -1
    WindowDrawImageAlpha(window_name, "location_icon", width / 2 + icon_point_x, height / 2 + icon_point_y, 0, 0, CONFIG.OPACITY / 100)

    if CONFIG.CIRCLE then
      WindowCircleOp(WIN, miniwin.circle_ellipse, consts.GetBorderWidth(), consts.GetBorderWidth(), CONFIG.WINDOW_WIDTH - consts.GetBorderWidth(), CONFIG.WINDOW_HEIGHT - consts.GetBorderWidth(), ColourNameToRGB("black"), 	miniwin.pen_inside_frame, 1, ColourNameToRGB("black"), miniwin.brush_solid)
      WindowImageFromWindow(window_name, "image", window_name)
      WindowRectOp(window_name, miniwin.rect_fill, 0, 0, 0, 0, ColourNameToRGB("black"))
      WindowCircleOp(window_name, miniwin.circle_ellipse, consts.GetBorderWidth(), consts.GetBorderWidth(), CONFIG.WINDOW_WIDTH - consts.GetBorderWidth(), CONFIG.WINDOW_HEIGHT - consts.GetBorderWidth(), ColourNameToRGB("white"), miniwin.pen_inside_frame, consts.GetBorderWidth(), ColourNameToRGB("white"), miniwin.brush_solid)
      WindowImageFromWindow(window_name, "mask", window_name)
      WindowRectOp(window_name, 2, 0, 0, 0, 0, ColourNameToRGB("black"))
      WindowMergeImageAlpha(window_name, "alpha", "mask", 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)
      WindowImageFromWindow(window_name, "alpha", window_name)      
      WindowImageFromWindow(window_name, "target", WIN)
      WindowDrawImage(window_name, "target", 0, 0, 0, 0, 1, 0, 0, 0, 0)
      WindowMergeImageAlpha(window_name, "image", "alpha", 0, 0, 0, 0, 1, 1, 0, 0, 0, 0)
      WindowImageFromWindow(WIN, "image", window_name)
      WindowDrawImage(WIN, "image", 0, 0, 0, 0, miniwin.image_transparent_copy, 0, 0, 0, 0)
      WindowCircleOp(WIN, miniwin.circle_ellipse, 0, 0, CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT, CONFIG.BORDER_COLOR, miniwin.pen_solid, consts.GetBorderWidth(), 0, miniwin.brush_null)
    else
      for i = 0, consts.GetBorderWidth() + 1 do
        WindowRectOp(WIN, miniwin.rect_frame, 0 + i, 0 + i, WindowInfo(WIN, 3) - i, WindowInfo(WIN, 4) - i, CONFIG.BORDER_COLOR)
      end
    end
    
    WindowAddHotspot(WIN, "world_map_hotspot", consts.GetBorderWidth(), consts.GetBorderWidth(), width - consts.GetBorderWidth(), height - consts.GetBorderWidth(), "", "", "", "", "OnMouseUp", "", miniwin.cursor_arrow, 0)  
    WindowScrollwheelHandler(WIN, "world_map_hotspot", "OnWheel")  
    
    WindowSetZOrder(WIN, 9999)
    
    WindowShow(WIN, true)
  end
end

drawDebugLabel = function(box)
  local label_width = WindowTextWidth(WIN, INFOFONT, box.label)
  local top, left = box.top, box.left

  if box.top < consts.GetBorderWidth() then
    top = box.bottom - LINE_HEIGHT
  end

  if box.left < consts.GetBorderWidth() then
    left = box.right - label_width - 16
  end

  WindowRectOp(WIN, miniwin.rect_fill, left, top, left + label_width + 16, top + LINE_HEIGHT, box.color)
  WindowText(WIN, INFOFONT, box.label, left + 8, top + 2, left + label_width + 16, top + LINE_HEIGHT, 0)  
end

tryShowCrystalMarker = function(window_name, max_x, max_y, center_x, center_y)
  if MARKERS.crystal == nil or MARKERS.crystal.x == nil or MARKERS.crystal.y == nil then return end
  if CURRENT_PLANE ~= "alyria" and CURRENT_PLANE ~= "underground" then return end

  local crystal_x = MARKERS.crystal.x / PLANE_DETAILS[CURRENT_PLANE].x * max_x
  local crystal_y = MARKERS.crystal.y / PLANE_DETAILS[CURRENT_PLANE].y * max_y
  local crystal_offset_x = crystal_x - center_x
  local crystal_offset_y = crystal_y - center_y

  WindowLoadImageMemory(window_name, "crystal_icon", ICON_CACHE.crystal)
  local icon_point_x = WindowImageInfo(window_name, "crystal_icon", 2) * -1/2
  local icon_point_y = WindowImageInfo(window_name, "crystal_icon", 3) * -1

  local width, height = WindowInfo(window_name, 3), WindowInfo(window_name, 4)
  local draw_x = width / 2 + crystal_offset_x + icon_point_x
  local draw_y = height / 2 + crystal_offset_y + icon_point_y

  if draw_x < consts.GetBorderWidth() or draw_x > (width - consts.GetBorderWidth()) or 
    draw_y < consts.GetBorderWidth() or draw_y > (height - consts.GetBorderWidth()) then
   return
  end

  WindowDrawImageAlpha(WIN, "crystal_icon", draw_x, draw_y, 0, 0, .8)
end

tryShowDestinationMarkers = function(window_name, max_x, max_y, center_x, center_y)
  local markers = { "one", "two", "three" }
  for _, marker in ipairs(markers) do
    if MARKERS[marker] == nil or MARKERS[marker].x == nil or MARKERS[marker].y == nil then return end

    local marker_x = MARKERS[marker].x / PLANE_DETAILS[CURRENT_PLANE].x * max_x
    local marker_y = MARKERS[marker].y / PLANE_DETAILS[CURRENT_PLANE].y * max_y
    local marker_offset_x = marker_x - center_x
    local marker_offset_y = marker_y - center_y

    WindowLoadImageMemory(window_name, marker .. "_icon", ICON_CACHE[marker])
    local icon_point_x = WindowImageInfo(window_name, marker .. "_icon", 2) * -1/2
    local icon_point_y = WindowImageInfo(window_name, marker.."_icon", 3) * -1

    local width, height = WindowInfo(window_name, 3), WindowInfo(window_name, 4)
    local draw_x = width / 2 + marker_offset_x + icon_point_x
    local draw_y = height / 2 + marker_offset_y + icon_point_y

    if draw_x < consts.GetBorderWidth() or draw_x > (width - consts.GetBorderWidth()) or 
      draw_y < consts.GetBorderWidth() or draw_y > (height - consts.GetBorderWidth()) then
    return
    end

    WindowDrawImageAlpha(WIN, marker .. "_icon", draw_x, draw_y, 0, 0, .8)
  end
end

drawTile = function(window_name, tile_x, tile_y, offset_x, offset_y, debug, color)
  if (offset_x > CONFIG.WINDOW_WIDTH - consts.GetBorderWidth()) or (offset_x + 1150 < consts.GetBorderWidth()) or
     (offset_y > CONFIG.WINDOW_HEIGHT - consts.GetBorderWidth()) or (offset_y + 750 < consts.GetBorderWidth()) then
    return nil
  end

  local tile = getMapTile(window_name, tile_x % (2^ZOOM_LEVEL[CURRENT_PLANE]), tile_y % (2^ZOOM_LEVEL[CURRENT_PLANE]), tile_x, tile_y, debug == "main")
  local flag = (CONFIG.STRETCH and miniwin.image_stretch) or miniwin.image_copy

  if tile == nil then
    return nil
  end

  WindowDrawImage(window_name, tile, 
    offset_x, 
    offset_y, 
    offset_x + 1150, 
    offset_y + 750, 
    flag)--miniwin.image_copy)--miniwin.image_stretch)

  return { 
    left = offset_x, 
    top = offset_y, 
    right = offset_x + 1150, 
    bottom = offset_y + 750,
    color = color,
    label = debug
  }
end

getMapTile = function(window_name, x, y, ox, oy, is_main)
  if not PLANE_DETAILS[CURRENT_PLANE].l and not is_main then
    -- no looping planes
    if (ox == nil or x < ox or (x == 0 and ox ~= 0)) or (oy == nil or y < oy or (y == 0 and oy ~= 0)) then
      return nil
    end
  end

  local filename = string.format("x%03dy%03d.png", x, y)
  local filepath = CONFIG.IMAGES_PATH .. CURRENT_PLANE .. "/" .. ZOOM_LEVEL[CURRENT_PLANE] .. "/" .. filename

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

  local ok = WindowLoadImage(window_name, filepath, filepath)
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

  saveMiniWindow()
  drawMiniWindow()
end

saveMiniWindow = function()
  serialization_helper.SaveSerializedVariable("worldmap_config", CONFIG)
  serialization_helper.SaveSerializedVariable("worldmap_zoom", ZOOM_LEVEL)
end

configure = function()
  local config = {
    Map = {
      IMAGES_PATH = { sort = -1, label = "Images Path", type = "string", raw_value = CONFIG.IMAGES_PATH },
      STRETCH = { sort = 0, label = "Stretch Image", type = "bool", raw_value = CONFIG.STRETCH },
      BORDER_COLOR = { sort = 1, type = "color", raw_value = CONFIG.BORDER_COLOR },
      HIDE_WILDS = { sort = 2, label = "Hide When Inside", type = "bool", raw_value = CONFIG.HIDE_WILDS },
      MAX_CACHE_SIZE = { sort = 3, type = "number", raw_value = CONFIG.MAX_CACHE_SIZE, min = 0, max = 200 },
      CIRCLE = { sort = 4, label = "Circular Map", type = "bool", raw_value = CONFIG.CIRCLE },
      OPACITY = { sort = 5, label = "Map Opacity", type = "number", raw_value = CONFIG.OPACITY, min = 10, max = 100 },
      FONT = { sort = 6, type = "font", value = CONFIG.FONT.name .. " (" .. CONFIG.FONT.size .. ")", raw_value = CONFIG.FONT },
      AUTOUPDATE = { sort = 7, label = "Auto Update", type = "bool", raw_value = CONFIG.AUTOUPDATE },
      DRAW_DEBUG = { sort = 8, label = "Draw Debug", type = "bool", raw_value = CONFIG.DRAW_DEBUG },
    },
    Position = {
      WINDOW_LEFT = { sort = 1, type = "number", raw_value = CONFIG.WINDOW_LEFT, min = 0, max = GetInfo(281) - 50 },
      WINDOW_TOP = { sort = 2, type = "number", raw_value = CONFIG.WINDOW_TOP, min = 0, max = GetInfo(280) - 50 },
      WINDOW_WIDTH = { sort = 3, type = "number", raw_value = CONFIG.WINDOW_WIDTH, min = 50, max = GetInfo(281) },
      WINDOW_HEIGHT = { sort = 4, type = "number", raw_value = CONFIG.WINDOW_HEIGHT, min = 50, max = GetInfo(280) },
    },
    Offsets = { }
  }

  for k, v in pairs(PLANE_DETAILS) do
    config.Offsets[k] = {}
    for i = 1, PLANE_DETAILS[k].z + 1 do
      config.Offsets[k]["Zoom_Level_" .. i] = {
        X = { sort = 1, type = "number", raw_value = CONFIG.OFFSETS[k][i].x, min = -1000, max = 1000 },
        Y = { sort = 2, type = "number", raw_value = CONFIG.OFFSETS[k][i].y, min = -1000, max = 1000 },
      }
    end    
  end
  
  config_window.Show(config, configureDone)
end

configureDone = function(group_id, option_id, config)
  local pattern = "^Offset_(%d)_%(([%w_]+)%)$"
  local zoom_level, plane = group_id:match(pattern)
  if zoom_level and plane then
    if option_id == "X" then
      CONFIG.OFFSETS[plane][zoom_level].x = config.raw_value
    else
      CONFIG.OFFSETS[plane][zoom_level].y = config.raw_value
    end
  else
    CONFIG[option_id] = config.raw_value
  end
  
  if option_id == "CIRCLE" then TILE_CACHE = {} end

  saveMiniWindow()
  createWindowAndFont()
  drawMiniWindow()
end

return {
  Initialize = initialize,
  SetCoords = setCoords,
  SetCrystalCoords = setCrystalCoords,
  SetDestinationCoords = setDestinationCoords,
  IsAutoUpdateEnabled = isAutoUpdateEnabled,
  HideWindow = hideWindow,
  Configure = configure,
}