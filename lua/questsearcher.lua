local https = require("ssl.https")
local ltn12 = require("ltn12")

local db

function finalize(stmt)
    if stmt then stmt:finalize() end
end

function exec_prepared(db, sql, ...)
    local stmt = db:prepare(sql)
    if stmt then
        stmt:bind_values(...)
        stmt:step()
        finalize(stmt)
    end
end

-- Utility: Fetch all rows
function fetch_all(stmt)
    local results = {}
    local result = stmt:step()
    while result == sqlite3.ROW do
        table.insert(results, stmt:get_named_values())
        result = stmt:step()
    end
    finalize(stmt)
    return results
end

-- HTML decoder
function strip_html(html)
    return html
        :gsub("<br ?/?>", "\n")
        :gsub("<[^>]->", "")
        :gsub("&mdash;", "—")
        :gsub("&nbsp;", " ")
        :gsub("&amp;", "&")
        :gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&quot;", '"')
        :gsub("&#(%d+);", function(n)
            return utf8.char(tonumber(n))
        end)
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$")
end

-- Find quest link on annwn.info
function find_quest_link(quest_number, quest_name)
    local encoded_name = quest_name:gsub(" ", "+")
    local url = "https://annwn.info/quest/search/?search=quest&keyword=" .. encoded_name
    local response = {}

    local _, status = https.request{
        url = url,
        sink = ltn12.sink.table(response)
    }

    if status ~= 200 then
        return nil, "Failed to fetch page: status " .. tostring(status)
    end

    local html = table.concat(response)
    local pattern = '<a href="/quest/(%d+)">([^<]+)'
    local fallback_id = nil

    for quest_id, link_text in html:gmatch(pattern) do
        local clean_text = Trim(link_text:gsub("%s+", " "):gsub("%s%[.*%]", ""):lower())
        local expected = Trim(quest_name:lower())
        local bracket_num = link_text:match("%[(%d+)%]")

        if clean_text == expected then
            if bracket_num and tonumber(bracket_num) == tonumber(quest_number) then
                return "/quest/" .. quest_id, quest_id
            elseif not bracket_num and not fallback_id then
                fallback_id = "/quest/" .. quest_id
            end
        end
    end

    return "/quest/" .. fallback_id, fallback_id
end

-- Fetch HTML from full URL path
function fetch_html(path)
    local url = "https://annwn.info" .. path
    local response = {}
    local _, status = https.request{
        url = url,
        sink = ltn12.sink.table(response),
        protocol = "tlsv1_2"
    }

    if status ~= 200 then
        return nil, "Failed to fetch quest page (status: " .. tostring(status) .. ")"
    end

    return table.concat(response)
end

-- Parse phases from HTML
function parse_phases(html)
    local phases = {}
    
    -- This pattern captures each entire phase block
    for phase_block in html:gmatch('<div[^>]-class="phase"[^>]*>(.-)</div>%s*</div>') do
        local phase = {
            text = nil,
            mobs = {},
            items = {},
            rooms = {},
            hints = {}
        }

        -- Extract main phase text (usually before <div class="phaseinfo...">)
        local main_line = phase_block:match('<a class=".-hints"[^>]*>.-</a>:%s*(.-)%s*<div')
        if main_line then
            phase.text = strip_html(main_line)
        end

        -- Extract all mobs
        for mob_html in phase_block:gmatch('<div class="phaseinfomob">(.-)</div>') do
            local mob = strip_html(mob_html)
            if mob ~= "" then
                table.insert(phase.mobs, mob)
            end
        end

        -- Extract all items
        for item_html in phase_block:gmatch('<div class="phaseinfoitem">(.-)</div>') do
            local item = strip_html(item_html)
            if item ~= "" then
                table.insert(phase.items, item)
            end
        end

        -- Extract all rooms
        for room_html in phase_block:gmatch('<div class="phaseinforoom">(.-)</div>') do
            local room = strip_html(room_html)
            if room ~= "" then
                table.insert(phase.rooms, room)
            end
        end

        -- Extract all hints
        for hint_html in phase_block:gmatch('<div class="phasehint">(.-)</div>') do
            local hint = strip_html(hint_html)
            if hint ~= "" then
                table.insert(phase.hints, hint)
            end
        end

        table.insert(phases, phase)
    end

    return phases
end


-- DB Initialization
function initDb()
    if db ~= nil then
        pcall(function()
            db:close()
        end)
        db = nil
    end

    db = assert(sqlite3.open(GetInfo(66) .. "annwn_quests.db"))
    db:exec("PRAGMA foreign_keys = ON")

    local columnExists = false
    for row in db:nrows("PRAGMA table_info(quests)") do
        if row.name == "annwn_id" then
            columnExists = true
            break
        end
    end

    if not columnExists then
        db:exec("DROP TABLE IF EXISTS quests")
    end

    local schema = [[
        CREATE TABLE IF NOT EXISTS quests (id INTEGER PRIMARY KEY, name TEXT, annwn_id TEXT);
        CREATE TABLE IF NOT EXISTS phases (
            id INTEGER PRIMARY KEY, quest_id INTEGER, phase_number INTEGER,
            description TEXT, UNIQUE(quest_id, phase_number),
            FOREIGN KEY(quest_id) REFERENCES quests(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS mobs (
            id INTEGER PRIMARY KEY, phase_id INTEGER, mob_name TEXT,
            UNIQUE(phase_id, mob_name),
            FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY, phase_id INTEGER, item_name TEXT,
            UNIQUE(phase_id, item_name),
            FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS rooms (
            id INTEGER PRIMARY KEY, phase_id INTEGER, room_name TEXT,
            UNIQUE(phase_id, room_name),
            FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS hints (
            id INTEGER PRIMARY KEY, phase_id INTEGER, hint_text TEXT,
            UNIQUE(phase_id, hint_text),
            FOREIGN KEY(phase_id) REFERENCES phases(id) ON DELETE CASCADE
        );
    ]]
    db:exec(schema)
end

-- Insert entities
function insert_entities(table_name, column_name, phase_id, values)
    for _, val in ipairs(values) do
        exec_prepared(db, string.format("INSERT INTO %s (phase_id, %s) VALUES (?, ?)", table_name, column_name), phase_id, val)
    end
end

-- Add quest to database
function addQuestToDb(questId, questName, phases, annwn_id)
  initDb()

  local questStmt = db:prepare("INSERT INTO quests (id, name, annwn_id) VALUES (?, ?, ?)")
  questStmt:bind_values(questId, questName, annwn_id)
  questStmt:step()
  questStmt:finalize()

  for phaseNumber, phase in ipairs(phases) do
    local phaseStmt = db:prepare("INSERT INTO phases (quest_id, phase_number, description) VALUES (?, ?, ?)")
    phaseStmt:bind_values(questId, phaseNumber, phase.text)
    phaseStmt:step()
    local phaseId = db:last_insert_rowid()
    phaseStmt:finalize()

    for _, mob in ipairs(phase.mobs or {}) do
      local mobStmt = db:prepare("INSERT INTO mobs (phase_id, mob_name) VALUES (?, ?)")
      mobStmt:bind_values(phaseId, mob)
      mobStmt:step()
      mobStmt:finalize()
    end

    for _, item in ipairs(phase.items or {}) do
      local itemStmt = db:prepare("INSERT INTO items (phase_id, item_name) VALUES (?, ?)")
      itemStmt:bind_values(phaseId, item)
      itemStmt:step()
      itemStmt:finalize()
    end

    for _, room in ipairs(phase.rooms or {}) do
      local roomStmt = db:prepare("INSERT INTO rooms (phase_id, room_name) VALUES (?, ?)")
      roomStmt:bind_values(phaseId, room)
      roomStmt:step()
      roomStmt:finalize()
    end

    for _, hint in ipairs(phase.hints or {}) do
      local hintStmt = db:prepare("INSERT INTO hints (phase_id, hint_text) VALUES (?, ?)")
      hintStmt:bind_values(phaseId, hint)
      hintStmt:step()
      hintStmt:finalize()
    end
  end

  db:close()
end


function getQuestFromDb(questId)
  initDb()

  local quest = {}
  local stmt = db:prepare("SELECT * FROM quests WHERE id = ?")
  stmt:bind_values(questId)

  if stmt:step() == sqlite3.ROW then
    quest.id = questId
    quest.name = stmt:get_named_values().name
    quest.annwn_id = stmt:get_named_values().annwn_id
    stmt:finalize()

    quest.phases = {}

    local phaseStmt = db:prepare("SELECT * FROM phases WHERE quest_id = ? ORDER BY phase_number")
    phaseStmt:bind_values(questId)

    while phaseStmt:step() == sqlite3.ROW do
      local phaseRow = phaseStmt:get_named_values()
      local phase = {
        text = phaseRow.description,
        mobs = {},
        items = {},
        rooms = {},
        hints = {}
      }

      local phaseId = phaseRow.id

      for mob in db:nrows("SELECT mob_name FROM mobs WHERE phase_id = " .. phaseId) do
        table.insert(phase.mobs, mob.mob_name)
      end

      for item in db:nrows("SELECT item_name FROM items WHERE phase_id = " .. phaseId) do
        table.insert(phase.items, item.item_name)
      end

      for room in db:nrows("SELECT room_name FROM rooms WHERE phase_id = " .. phaseId) do
        table.insert(phase.rooms, room.room_name)
      end

      for hint in db:nrows("SELECT hint_text FROM hints WHERE phase_id = " .. phaseId) do
        table.insert(phase.hints, hint.hint_text)
      end

      table.insert(quest.phases, phase)
    end

    phaseStmt:finalize()
    db:close()
    return quest
  else
    stmt:finalize()
    db:close()
    return nil
  end
end


-- Remove quest
function removeQuestFromDb(quest_id)
    initDb()
    db:exec("BEGIN")
    exec_prepared(db, "DELETE FROM quests WHERE id = ?", quest_id)
    db:exec("COMMIT")
    db:close()
    return true
end

-- Main interface
function getQuestInfo(quest_num, quest_name)
    initDb()
    local quest = getQuestFromDb(quest_num)

    if quest == nil then
        local link, annwn_id = find_quest_link(quest_num, quest_name)
        if not link then
            return nil
        end

        local html, fetch_err = fetch_html(link)
        if not html then
            Note(fetch_err)
            return nil
        end

        local phases = parse_phases(html)
        addQuestToDb(quest_num, quest_name, phases, annwn_id)
        quest = { phases = phases, annwn_id = annwn_id }
    end

    return quest.phases, quest.annwn_id
end
