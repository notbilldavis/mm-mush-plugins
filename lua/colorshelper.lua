function strip_colors(msg)
  local res = ""

  res = string.gsub(msg, "|[xz]%d%d%d", "")
  res = string.gsub(res, "|[%d%a]", "")
  res = Trim(res)

  return res, white
end

function strip_crlfs(msg)
  msg = string.gsub(msg, "\r", "|")
  msg = string.gsub(msg, "\n", "|")
  msg = msg .. "|"

  while (string.find(msg, "||")) do
    msg = string.gsub(msg, "||", "|")
  end

  return msg
end

local code_to_name = {
  ["1"] = "maroon",
  ["2"] = "green",
  ["3"] = "olive",
  ["4"] = "navy",
  ["5"] = "purple",
  ["6"] = "teal",
  ["7"] = "silver",
  ["B"] = "blue",
  ["R"] = "red",
  ["C"] = "cyan",
  ["M"] = "magenta",
  ["Y"] = "yellow",
  ["W"] = "white",
  ["G"] = "lime",
  ["b"] = "navy",
  ["r"] = "maroon",
  ["c"] = "teal",
  ["m"] = "purple",
  ["y"] = "olive",
  ["w"] = "silver",
  ["g"] = "green",
  ["D"] = "gray",
}

function fg_mm_to_name(color)
  local res = code_to_name[color]

  return res
end

function bg_mm_to_name(color)
  local res = code_to_name[color]

  return res
end

local compatibility_16_to_rgb = {
  [0] = 0, -- black
  [1] = 128, -- maroon
  [2] = 32768, -- green
  [3] = 32896, -- olive
  [4] = 8388608, -- navy
  [5] = 8388736, -- purple
  [6] = 8421376, -- teal
  [7] = 12632256, -- silver
  [8] = 8421504, -- gray
  [9] = 255, -- red
  [10] = 65280, -- lime
  [11] = 65535, -- yellow
  [12] = 16711680, -- blue
  [13] = 16711935, -- magenta
  [14] = 16776960, -- cyan
  [15] = 16777215, -- white
}

function x256_to_rgb(x256)
  local r, g, b, rgb

  if (x256 >= 0) and (x256 <= 15) then
    -- compatibility 16
    rgb = compatibility_16_to_rgb[x256]

  elseif (x256 >= 16) and (x256 <= 231) then
    -- cube
    x256 = x256 - 16

    r = math.floor(x256 / 6 / 6)
    x256 = x256 - (r * 6 * 6)
    g = math.floor(x256 / 6)
    b = x256 - (g * 6)

    rgb = (256 * 256 * to255(b)) + (256 * to255(g)) + to255(r)

  elseif (x256 >= 232) and (x256 <= 255) then
    -- grayscale
    x256 = x256 - 232

    rgb = (256 * 256 * to255gray(x256)) + (256 * to255gray(x256)) + to255gray(x256)
  end

  return rgb
end

function to255(num)
  return num * 51
end

function to255gray(num)
  return 8 + (num * 10)
end