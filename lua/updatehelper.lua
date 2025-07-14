local https = require("ssl.https")
local ltn12 = require("ltn12")

local UPD = {}

function UPD.Update(files)
  local success, result = pcall(function()
    
    local function check(local_filename, remote_url)
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
        ColourNote("red" , "black", "There was an error accessing " .. remote_url .. " - code: " .. dl_res)
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
          ColourNote("red" , "black", "There was an error updating: " .. res .. " - code: " .. res_code .. "! Manually update.")
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

    local is_updated = false
    for _, update_file in ipairs(files) do
      if check(update_file["local_file"], update_file["remote_file"]) then
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

return UPD