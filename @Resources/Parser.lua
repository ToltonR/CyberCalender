-- icsParser.lua
-- A module for fetching and parsing ICS calendar files
-- Usage:
--   local icsParser = require("icsParser")
--   local result = icsParser.fetchAndParse(url, bearerToken, todayOverride)
--   print(icsParser.toJson(result))
--
-- Standalone usage:
--   Configure the URL below and run: lua icsParser.lua

-- ===== CONFIGURE HERE =====
local DEFAULT_ICS_URL = "https://calendar.google.com/calendar/ical/gouravsarkar67%40gmail.com/private-ee3c013715a9d131a06e398956d3c948/basic.ics"
local DEFAULT_BEARER_TOKEN = nil -- e.g. "ya29...." or nil
local DEFAULT_TODAY_OVERRIDE = nil -- e.g. "2025-10-25" or nil
local DEFAULT_UPCOMING_LIMIT = 3
-- ==========================

local M = {}

-- ---------- Helpers ----------
local function trim(s)
  if not s then return s end
  return s:match("^%s*(.-)%s*$")
end

local function isArray(t)
  if type(t) ~= "table" then return false end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

local function jsonEscape(s)
  s = tostring(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n"):gsub("\r", ""):gsub("\t", "\\t")
  return s
end

local function toJsonPretty(value, indent)
  indent = indent or 0
  local pad = string.rep("  ", indent)
  local t = type(value)
  if t == "nil" then return "null"
  elseif t == "number" or t == "boolean" then return tostring(value)
  elseif t == "string" then return '"' .. jsonEscape(value) .. '"'
  elseif t == "table" then
    if isArray(value) then
      if #value == 0 then return "[]" end
      local parts = {}
      for i = 1, #value do
        parts[#parts + 1] = pad .. "  " .. toJsonPretty(value[i], indent + 1)
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    else
      local parts, keys = {}, {}
      for k in pairs(value) do
        if type(k) == "string" then keys[#keys + 1] = k end
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        parts[#parts + 1] = pad .. "  " .. '"' .. jsonEscape(k) .. '": ' .. toJsonPretty(value[k], indent + 1)
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
  else
    return '"' .. jsonEscape(tostring(value)) .. '"'
  end
end

-- ---------- Fetch ICS (luasocket then curl fallback) ----------
local function fetch_with_luasocket(url, token)
  local ok, http = pcall(require, "socket.http")
  if not ok or not http then return nil, "luasocket not available" end
  local ltn12_ok, ltn12 = pcall(require, "ltn12")
  if not ltn12_ok then return nil, "ltn12 not available" end
  local resp = {}
  local headers = {}
  if token and token ~= "" then headers["Authorization"] = "Bearer " .. token end
  local req = {
    url = url,
    sink = ltn12.sink.table(resp),
    headers = headers,
    redirect = true
  }
  local ok_req, code, h = http.request(req)
  if not ok_req then
    return nil, ("http.request failed: %s"):format(tostring(code))
  end
  local body = table.concat(resp)
  return body, nil
end

local function fetch_with_curl(url, token)
  local hdr = ""
  if token and token ~= "" then hdr = ' -H "Authorization: Bearer ' .. token:gsub('"', '\\"') .. '"' end
  local cmd = 'curl -fsS -L' .. hdr .. ' "' .. url:gsub('"', '\\"') .. '"'
  local p = io.popen(cmd, "r")
  if not p then return nil, "failed to run curl" end
  local out = p:read("*a")
  local ok_close, _, _ = p:close()
  return out, nil
end

local function fetch_ics(url, token)
  local body, err = fetch_with_luasocket(url, token)
  if body and body ~= "" then return body end
  local body2, err2 = fetch_with_curl(url, token)
  if body2 and body2 ~= "" then return body2 end
  return nil, ("fetch failed: %s ; %s"):format(tostring(err), tostring(err2))
end

-- ---------- Time parsing & formatting (UTC->IST conversion for Z) ----------
local function parseDtRaw(s)
  if not s then return nil end
  local out = { date = nil, time = nil, isAllDay = false, isUtc = false }
  s = trim(s)
  local y, m, d = s:match("^(%d%d%d%d)(%d%d)(%d%d)$")
  if y then
    out.date = ("%s-%s-%s"):format(y, m, d)
    out.isAllDay = true
    return out
  end
  local y2, mo, da, hh, mi, ss = s:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z$")
  if y2 then
    out.date = ("%s-%s-%s"):format(y2, mo, da)
    out.time = ("%s:%s:%s"):format(hh, mi, ss)
    out.isUtc = true
    return out
  end
  local y3, mo3, da3, hh3, mi3, ss3 = s:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)$")
  if y3 then
    out.date = ("%s-%s-%s"):format(y3, mo3, da3)
    out.time = ("%s:%s:%s"):format(hh3, mi3, ss3)
    return out
  end
  return out
end

local function convertUtcToIst(time)
  if not time then return time end
  local h, m = time:match("^(%d%d):(%d%d)")
  if not h then return time end
  h, m = tonumber(h), tonumber(m)
  local total = h * 60 + m + 330 -- +5h30m
  total = total % (24 * 60)
  local hh = math.floor(total / 60)
  local mm = total % 60
  return string.format("%02d:%02d", hh, mm)
end

local function formatTimeRange(start, finish, isAllDay, startIsUtc, endIsUtc)
  if isAllDay then return "All day" end
  local function short(t) return t and t:sub(1, 5) or nil end
  if startIsUtc then start = convertUtcToIst(start) end
  if endIsUtc then finish = convertUtcToIst(finish) end
  if start and finish then return short(start) .. " – " .. short(finish)
  elseif start then return short(start)
  else return nil end
end

-- ---------- Public Functions ----------

-- Parse ICS content and return array of events
function M.parseIcs(body)
  if not body then return nil, "no content provided" end
  
  -- normalize and unfold folded lines
  body = body:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n[ \t]", "")
  
  local events = {}
  for block in body:gmatch("BEGIN:VEVENT(.-)END:VEVENT") do
    if type(block) == "string" then
      local e = {}
      e.uid = trim(block:match("UID:([^\n\r]+)"))
      e.dtStartRaw = trim(block:match("DTSTART[^:]*:([^\n\r]+)"))
      e.dtEndRaw = trim(block:match("DTEND[^:]*:([^\n\r]+)"))
      e.summary = trim(block:match("SUMMARY:([^\n\r]+)"))
      e.description = trim(block:match("DESCRIPTION:([^\n\r]+)"))
      e.location = trim(block:match("LOCATION:([^\n\r]+)"))
      
      e._start = parseDtRaw(e.dtStartRaw)
      e._end = parseDtRaw(e.dtEndRaw)
      e.dtStartDate = e._start and e._start.date or nil
      e.dtEndDate = e._end and e._end.date or nil
      e.isAllDay = (e._start and e._start.isAllDay) or false
      
      e.timeText = formatTimeRange(
        e._start and e._start.time,
        e._end and e._end.time,
        e.isAllDay,
        e._start and e._start.isUtc,
        e._end and e._end.isUtc
      )
      
      table.insert(events, e)
    end
  end
  
  return events
end

-- Filter events into today and upcoming
function M.filterEvents(events, today)
  today = today or os.date("%Y-%m-%d")
  
  local todayEvents, upcomingEvents = {}, {}
  for _, e in ipairs(events) do
    if e.dtStartDate == today then
      table.insert(todayEvents, e)
    elseif e.dtStartDate and e.dtStartDate > today then
      table.insert(upcomingEvents, e)
    end
  end
  
  table.sort(upcomingEvents, function(a, b) return (a.dtStartRaw or "") < (b.dtStartRaw or "") end)
  table.sort(todayEvents, function(a, b) return (a.dtStartRaw or "") < (b.dtStartRaw or "") end)
  
  return todayEvents, upcomingEvents
end

-- Create slim event object
local function slim(e)
  if not e then return nil end
  return {
    summary = e.summary,
    dtStartDate = e.dtStartDate,
    dtEndDate = e.dtEndDate,
    timeText = e.timeText,
    description = e.description,
    location = e.location
  }
end

-- Format output
function M.formatOutput(todayEvents, upcomingEvents, today, limit)
  limit = limit or 3
  today = today or os.date("%Y-%m-%d")
  
  local next = {}
  for i = 1, math.min(limit, #upcomingEvents) do
    table.insert(next, upcomingEvents[i])
  end
  
  local out = {
    todayDate = today,
    todayCount = #todayEvents,
    upcomingCount = #upcomingEvents,
    todayEvents = {},
    upcomingEvents = {}
  }
  
  for _, e in ipairs(todayEvents) do
    table.insert(out.todayEvents, slim(e))
  end
  
  for _, e in ipairs(next) do
    table.insert(out.upcomingEvents, slim(e))
  end
  
  return out
end

-- Fetch and parse ICS from URL
function M.fetchIcs(url, token)
  return fetch_ics(url, token)
end

-- All-in-one: fetch, parse, and format
function M.fetchAndParse(url, token, todayOverride, upcomingLimit)
  local body, err = fetch_ics(url, token)
  if not body then
    return nil, err
  end
  
  local events = M.parseIcs(body)
  if not events then
    return nil, "failed to parse ICS"
  end
  
  local today = todayOverride or os.date("%Y-%m-%d")
  local todayEvents, upcomingEvents = M.filterEvents(events, today)
  
  return M.formatOutput(todayEvents, upcomingEvents, today, upcomingLimit)
end

-- Convert to JSON string
function M.toJson(obj)
  return toJsonPretty(obj)
end

-- ---------- Main function for standalone usage ----------
function M.main(args)
  args = args or arg or {}
  
  -- Use configured defaults or command-line arguments
  local url = args[1] or DEFAULT_ICS_URL
  local token = args[2] or DEFAULT_BEARER_TOKEN
  local todayOverride = args[3] or DEFAULT_TODAY_OVERRIDE
  local upcomingLimit = (args[4] and tonumber(args[4])) or DEFAULT_UPCOMING_LIMIT
  
  -- Validate URL
  if not url or url == "" then
    io.stderr:write([[
Error: No ICS URL configured!

Please either:
1. Configure DEFAULT_ICS_URL in the file, or
2. Pass URL as command-line argument

Usage: lua icsParser.lua [ICS_URL] [BEARER_TOKEN] [TODAY_DATE] [UPCOMING_LIMIT]

Arguments:
  ICS_URL         - URL to the ICS calendar file (or configure in file)
  BEARER_TOKEN    - Optional: Bearer token for Authorization header
  TODAY_DATE      - Optional: Override for "today" date (YYYY-MM-DD format)
  UPCOMING_LIMIT  - Optional: Number of upcoming events to show (default: 3)

Examples:
  lua icsParser.lua
  lua icsParser.lua "https://example.com/cal.ics"
  lua icsParser.lua "https://example.com/cal.ics" "ya29.token123"
  lua icsParser.lua "" "" "2025-10-25" 5
]])
    os.exit(1)
  end
  
  -- Handle empty string arguments
  if token == "" then token = nil end
  if todayOverride == "" then todayOverride = nil end
  
  -- Fetch and parse
  local result, err = M.fetchAndParse(url, token, todayOverride, upcomingLimit)
  if not result then
    io.stderr:write("Error: " .. tostring(err) .. "\n")
    os.exit(1)
  end
  
  -- Output JSON
  print(M.toJson(result))
  os.exit(0)
end

-- Check if this script is being run directly (not required as a module)
if not pcall(debug.getlocal, 4, 1) then
  M.main(arg)
end

return M