local https = require("ssl.https")
local ltn12 = require("ltn12")

local updateAndRequire, update, update_legacy, check_file

local github_url = "https://raw.githubusercontent.com/notbilldavis/mm-mush-plugins/refs/heads/main/"

updateAndRequire = function(local_path, file_name)
  if not local_path or not file_name then
    return false, nil
  end

  local success, result = pcall(check_file, local_path .. file_name, github_url .. file_name)
  if not success then
    return false, nil
  end
  
  return pcall(require, file_name:gsub("%.lua$", ""))
end

update = function(local_path, file_name)
  if file_name == nil and type(local_path) == "table" then
    update_legacy(local_path)
  else
    return pcall(check_file, local_path .. file_name, github_url .. file_name)
  end
end

update_legacy = function(files)
  local success, result = pcall(function()
    local is_updated = false
    for _, update_file in ipairs(files) do
      if check_file(update_file["local_file"], update_file["remote_file"]) then
        is_updated = true
      end
    end

    if is_updated then
      ColourNote("green", "black", "The '" .. GetPluginName() .. "' plugin has been updated and should be reinstalled.")
    else
      Note("No updates available for '" .. GetPluginName() .. "' at this time.")
    end    
  end)
end

check_file = function(local_filename, remote_url)
    local f = io.open(local_filename, "rb")
    if not f then return nil end
    local local_script = f:read("*all"):gsub("\r\n", "\n")
    f:close()

    local response = {}
    local _, dl_res = https.request {
        url = remote_url,
        sink = ltn12.sink.table(response)
    }

    if (dl_res ~= 200) then
      ColourNote("red" , "black", GetPluginName() .. ": [" .. dl_res .. "] There was an error updating from: " .. remote_url)
      return false
    end

    local remote_script = table.concat(response):gsub("\r\n", "\n")

    if not remote_script then
      return false
    end

    if local_script ~= remote_script then
      os.remove(local_filename .. ".backup")
      os.rename(local_filename, local_filename .. ".backup")
      local new_file, res, res_code = io.open(local_filename, "wb")
      if (f == nil) then
        ColourNote("red" , "black",  GetPluginName() .. ": [" .. res_code .. "] There was an error updating: " .. res .. "! Manually update the file and try again.")
        os.rename(local_filename .. ".backup", local_filename)
        return false
      end

      new_file:write(remote_script)
      new_file:flush()
      new_file:close()
      return true
    end

    return false
  end

return {
  version = 2,
  Update = update,
  UpdateAndRequire = updateAndRequire
}