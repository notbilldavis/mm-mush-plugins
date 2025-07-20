local https = require("ssl.https")
local ltn12 = require("ltn12")

local db

-- Function to fetch HTML and extract correct quest link
function find_quest_link(quest_number, quest_name)
    -- Replace spaces with plus for URL encoding
    local encoded_name = quest_name:gsub(" ", "+")
    local url = "https://annwn.info/quest/search/?search=quest&keyword=" .. encoded_name

    -- Fetch HTML content
    local response = {}
    local _, status = https.request{
        url = url,
        sink = ltn12.sink.table(response)
    }

    if status ~= 200 then
        return nil, "Failed to fetch page: status " .. tostring(status)
    end

    local html = table.concat(response)

    -- Prepare pattern to find matching <a href=...> lines
    local links = {}
    local pattern = '<a href="/quest/(%d+)">([^<]+)'
    local matches = html:gmatch(pattern)
    local no_num = nil

    for quest_id, link_text in matches do
        local quest_text_cleaned = link_text:gsub("%s+", " "):gsub("%s%[.*%]", ""):lower()
        local expected_name = quest_name:lower()

        if quest_text_cleaned == expected_name then
            -- Now check for [3050] part if it exists
            local found_number = link_text:match("%[(%d+)%]")
            if found_number == nil and no_num == nil then
                no_num = quest_id
            elseif tonumber(found_number) == tonumber(quest_number) then
                return "/quest/" .. quest_id
            end
        end
    end

    return no_num, "No matching quest found"
end

local function fetch_html(path)
    local url = "https://annwn.info" .. path
    local response = {}
    local res, status_code, headers = https.request{
        url = url,
        sink = ltn12.sink.table(response),
        protocol = "tlsv1_2"  -- Ensures secure connection
    }

    if status_code ~= 200 then
        return nil, "Failed to fetch quest page (status: " .. tostring(status_code) .. ")"
    end

    return table.concat(response)
end

local function parse_phases(html)
    local phases = {}

    for phase_block in html:gmatch('<div class="phase".-<a class="hints".-</a>.-</div>%s*</div>') do
        local phase = {
            text = nil,
            mobs = {},
            items = {},
            rooms = {},
            hints = {}
        }

        -- Extract the main text (first <a class="hints"...> line)
        local main_line = phase_block:match('<a class="hints".-</a>:%s*(.-)%s*<div')
        if main_line then
            phase.text = strip_html(main_line:gsub("%s+", " "):gsub("&mdash;", "-"))
        end

        -- Extract phaseinfomob
        for mob_info_match in phase_block:gmatch('<div class="phaseinfomob">(.-)</div>') do
            local cleaned_mob_info = strip_html(mob_info_match:gsub("%s+", " "):gsub("&mdash;", "-"))
            table.insert(phase.mobs, cleaned_mob_info)
        end

        -- Extract phaseinfoitem
        for item_info_match in phase_block:gmatch('<div class="phaseinfoitem">(.-)</div>') do
            local cleaned_item_info = strip_html(item_info_match:gsub("%s+", " "):gsub("&mdash;", "-"))
            table.insert(phase.items, cleaned_item_info)
        end

        -- Extract phaseinforoom
        for item_info_match in phase_block:gmatch('<div class="phaseinforoom">(.-)</div>') do
            local cleaned_room_info = strip_html(item_info_match:gsub("%s+", " "):gsub("&mdash;", "-"))
            table.insert(phase.rooms, cleaned_room_info)
        end

        -- Extract all hints
        for hint_match in phase_block:gmatch('<div class="phasehint">(.-)</div>') do
            local cleaned_hint = strip_html(hint_match:gsub("%s+", " "):gsub("&mdash;", "-"))
            table.insert(phase.hints, cleaned_hint)
        end

        table.insert(phases, phase)
    end

    return phases
end

function getQuestInfo(quest_num, quest_name)
  initDb()

  local quest = getQuestFromDb(quest_num)
  if quest == nil then
    local link, err = find_quest_link(quest_num, quest_name)
    if not link then
      Note(err)
      return nil
    end

    local html, fetch_err = fetch_html(link)
    if not html then
      Note(fetch_err)
      return nil
    end

    local phases = parse_phases(html)

    addQuestToDb(quest_num, quest_name, phases)

    quest =  { phases = phases }
  end

  return quest.phases
end

function initDb()
  db = assert(sqlite3.open(GetInfo(66) .. "annwn_quests.db"))

  db:exec("PRAGMA foreign_keys = ON")

  db:exec[[
      CREATE TABLE IF NOT EXISTS quests (
          id INTEGER PRIMARY KEY,
          name TEXT
      );

      CREATE TABLE IF NOT EXISTS phases (
          id INTEGER PRIMARY KEY,
          quest_id INTEGER,
          phase_number INTEGER,
          description TEXT,
          UNIQUE(quest_id, phase_number)
          FOREIGN KEY(quest_id) REFERENCES quests(id)
      );

      CREATE TABLE IF NOT EXISTS mobs (
          id INTEGER PRIMARY KEY,
          phase_id INTEGER,
          mob_name TEXT,
          UNIQUE(phase_id, mob_name)
          FOREIGN KEY(phase_id) REFERENCES phases(id)
      );

      CREATE TABLE IF NOT EXISTS items (
          id INTEGER PRIMARY KEY,
          phase_id INTEGER,
          item_name TEXT,
          UNIQUE(phase_id, item_name)
          FOREIGN KEY(phase_id) REFERENCES phases(id)
      );

      CREATE TABLE IF NOT EXISTS rooms (
          id INTEGER PRIMARY KEY,
          phase_id INTEGER,
          room_name TEXT,
          UNIQUE(phase_id, room_name)
          FOREIGN KEY(phase_id) REFERENCES phases(id)
      );

      CREATE TABLE IF NOT EXISTS hints (
          id INTEGER PRIMARY KEY,
          phase_id INTEGER,
          hint_text TEXT,
          UNIQUE(phase_id, hint_text)
          FOREIGN KEY(phase_id) REFERENCES phases(id)
      );
  ]]

  local function needsMigration(child_table, from_col, parent_table, to_col)
    for row in db:nrows("PRAGMA foreign_key_list(" .. child_table .. ")") do
      if row.table == parent_table and row.from == from_col and row.to == to_col then
        return row.on_delete:upper() ~= "CASCADE"
      end
    end
    return true
  end

  local migrations = {}

  if needsMigration("phases", "quest_id", "quests", "id") then
    migrations["phases"] = [[
      CREATE TABLE phases (
        id INTEGER PRIMARY KEY,
        quest_id INTEGER,
        phase_number INTEGER,
        description TEXT,
        UNIQUE(quest_id, phase_number),
        FOREIGN KEY(quest_id) REFERENCES quests(id) ON DELETE CASCADE
      );
    ]]
  end

  local dependents = { "mobs", "items", "rooms" }

  for _, tbl in ipairs(dependents) do
    if needsMigration(tbl, "phase_id", "phases", "id") then
      migrations[tbl] = string.format([[
        CREATE TABLE %s (
          id INTEGER PRIMARY KEY,
          phase_id INTEGER,
          %s_name TEXT,
          UNIQUE(phase_id, %s_name),
          FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
        );
      ]], tbl, tbl:sub(1, -2), tbl:sub(1, -2))
    end
  end

  if needsMigration("hints", "phase_id", "phases", "id") then
    migrations["hints"] = [[
      CREATE TABLE hints (
        id INTEGER PRIMARY KEY,
        phase_id INTEGER,
        hint_text TEXT,
        UNIQUE(phase_id, hint_text),
        FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
      );
    ]]
    end

  for table_name, create_stmt in pairs(migrations) do
    db:exec("BEGIN;")

    local old_table = table_name .. "_old"
    db:exec("ALTER TABLE " .. table_name .. " RENAME TO " .. old_table .. ";")
    db:exec(create_stmt)

    local columns = {}
    for row in db:nrows("PRAGMA table_info(" .. old_table .. ")") do
      table.insert(columns, row.name)
    end
    local col_list = table.concat(columns, ", ")
    db:exec(string.format("INSERT INTO %s (%s) SELECT %s FROM %s;", table_name, col_list, col_list, old_table))

    db:exec("DROP TABLE " .. old_table .. ";")
    db:exec("COMMIT;")
  end
end

function getQuestFromDb(questId)
  if db == nil then initDb() end

  local success, result = pcall(function()
    local quest = {}

    local stmt = db:prepare("SELECT * FROM quests WHERE id = ?")
    stmt:bind_values(questId)
    local result = stmt:step()

    if result == sqlite3.ROW then
      quest.id = questId
      quest.name = stmt:get_columns()[2]

      local phases = {}
      local phaseStmt = db:prepare("SELECT * FROM phases WHERE quest_id = ? ORDER BY phase_number")
      phaseStmt:bind_values(questId)
      local phaseResult = phaseStmt:step()

      while phaseResult == sqlite3.ROW do
        local phase = {}
        phase.text = phaseStmt:get_columns()[3]

        local phaseId = phaseStmt:get_columns()[1]
        local mobs = {}
        local mobStmt = db:prepare("SELECT mob_name FROM mobs WHERE phase_id = ?")
        mobStmt:bind_values(phaseId)
        local mobResult = mobStmt:step()

        while mobResult == sqlite3.ROW do
          table.insert(mobs, mobStmt:get_columns()[1]) 
          mobResult = mobStmt:step()
        end
        phase.mobs = mobs

        local items = {}
        local itemStmt = db:prepare("SELECT item_name FROM items WHERE phase_id = ?")
        itemStmt:bind_values(phaseId)
        local itemResult = itemStmt:step()

        while itemResult == sqlite3.ROW do
          table.insert(items, itemStmt:get_columns()[1]) 
          itemResult = itemStmt:step()
        end
        phase.items = items

        local rooms = {}
        local roomStmt = db:prepare("SELECT room_name FROM rooms WHERE phase_id = ?")
        roomStmt:bind_values(phaseId)
        local roomResult = roomStmt:step()

        while roomResult == sqlite3.ROW do
          table.insert(rooms, roomStmt:get_columns()[1]) 
          roomResult = roomStmt:step()
        end
        phase.rooms = rooms

        local hints = {}
        local hintStmt = db:prepare("SELECT hint_text FROM hints WHERE phase_id = ?")
        hintStmt:bind_values(phaseId)
        local hintResult = hintStmt:step()

        while hintResult == sqlite3.ROW do
          table.insert(hints, hintStmt:get_columns()[1])
          hintResult = hintStmt:step()
        end
      
        phase.hints = hints

        table.insert(phases, phase)

        phaseResult = phaseStmt:step()
      end

      quest.phases = phases
    else
      return nil
    end

    return quest
  end)

  if success then
    return result
  else
    return nil
  end  
end

function addQuestToDb(questId, questName, phases)
  local questStmt = db:prepare("INSERT INTO quests (id, name) VALUES (?, ?)")
  questStmt:bind_values(questId, questName)
  questStmt:step()
    
  for phaseNumber, phase in ipairs(phases) do
    local phaseStmt = db:prepare("INSERT INTO phases (quest_id, phase_number, description) VALUES (?, ?, ?)")
    phaseStmt:bind_values(questId, phaseNumber, phase.text)
    phaseStmt:step()
        
    local phaseId = db:last_insert_rowid()

    for _, mob in ipairs(phase.mobs) do
      local mobStmt = db:prepare("INSERT INTO mobs (phase_id, mob_name) VALUES (?, ?)")
      mobStmt:bind_values(phaseId, mob)
      mobStmt:step()
    end

    for _, item in ipairs(phase.items) do
      local itemStmt = db:prepare("INSERT INTO items (phase_id, item_name) VALUES (?, ?)")
      itemStmt:bind_values(phaseId, item)
      itemStmt:step()
    end

    for _, room in ipairs(phase.rooms) do
      local roomStmt = db:prepare("INSERT INTO rooms (phase_id, room_name) VALUES (?, ?)")
      roomStmt:bind_values(phaseId, room)
      roomStmt:step()
    end

    for _, hint in ipairs(phase.hints) do
      local hintStmt = db:prepare("INSERT INTO hints (phase_id, hint_text) VALUES (?, ?)")
      hintStmt:bind_values(phaseId, hint)
      hintStmt:step()      
    end
  end
end

function removeQuestFromDb(quest_id)
  local success = true
  if db == nil then initDb() end
  db:exec("PRAGMA foreign_keys = ON")

  local stmt = db:prepare("DELETE FROM quests WHERE id = ?")
  if stmt then
    stmt:bind_values(quest_id)
    stmt:step()
    stmt:finalize()
  else
    success = false
  end
  return success
end

function strip_html(html)
    return html
        :gsub("<br ?/?>", "\n")         -- turn <br> into newlines
        :gsub("<[^>]->", "")            -- remove all other tags
        :gsub("&mdash;", "—")           -- decode common HTML entity
        :gsub("&nbsp;", " ")            -- non-breaking space
        :gsub("&amp;", "&")             -- ampersand
        :gsub("&lt;", "<")              -- less than
        :gsub("&gt;", ">")              -- greater than
        :gsub("&quot;", '"')            -- quotes
        :gsub("&#(%d+);", function(n)   -- numeric HTML entity
            return utf8.char(tonumber(n))
        end)
        :gsub("%s+", " ")               -- normalize whitespace
        :gsub("^%s+", ""):gsub("%s+$", "") -- trim
end