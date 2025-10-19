-- Calendar Grid Generation for Rainmeter
-- ===============================================

-- Debug function to show selected date and events
function GetDebugOutput()
  local selected = GetSelectedDate()
  local today = os.date("%Y-%m-%d")

  local output = ""
  if selected == today then
    output = "It's today - " .. selected
  else
    output = selected
  end

  -- Get events for the selected date
  local result = GetParsedResultJson(selected)
  if result and result.todayEvents then
    for i, event in ipairs(result.todayEvents) do
      output = output .. "\n" .. (event.summary or "")
      if event.timeText then
        output = output .. " - " .. event.timeText
      end
    end
  end

  return output
end

-- Selected date for viewing events (YYYY-MM-DD format)
local selectedDate = nil

function Initialize()
    currentMonth = tonumber(os.date('%m'))
    currentYear = tonumber(os.date('%Y'))
    todayDay = tonumber(os.date('%d'))

    -- Initialize selectedDate to today
    selectedDate = os.date("%Y-%m-%d")

    -- Debug: Log the initialization
    print('Calendar initialized: ' .. currentMonth .. '/' .. todayDay .. '/' .. currentYear)
end

-- Set selected date when user clicks on a date (index is 0-41, the cell index)
function SetSelectedDate(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
    local dayNum = index - firstDayOfWeek + 1

    -- Use the same logic as IsInCurrentMonth to determine which month/year
    if dayNum >= 1 and dayNum <= daysInMonth then
        -- Current month (blue date)
        selectedDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, dayNum)
    elseif dayNum < 1 then
        -- Previous month (grey date) - flip to previous month
        PrevMonth()
        local prevMonthDays = GetDaysInMonth(currentMonth, currentYear)
        local actualDay = prevMonthDays + dayNum
        selectedDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, actualDay)
    else
        -- Next month (grey date) - flip to next month
        NextMonth()
        local actualDay = dayNum - daysInMonth
        selectedDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, actualDay)
    end

    -- Check if the selected date is today
    if selectedDate == os.date("%Y-%m-%d") then
        print('Selected date: It\'s today - ' .. selectedDate)
    else
        print('Selected date: ' .. selectedDate)
    end
end

-- Get the currently selected date
function GetSelectedDate()
    return selectedDate or os.date("%Y-%m-%d")
end

function Update()
    -- Update today's day number in case it's a new day
    local nowDay = tonumber(os.date('%d'))
    local nowMonth = tonumber(os.date('%m'))
    local nowYear = tonumber(os.date('%Y'))

    -- If we're viewing the current month, update today
    if currentMonth == nowMonth and currentYear == nowYear then
        todayDay = nowDay
    end

    -- Return the month and year string
    return GetMonthYearString()
end

-- Get the number of days in a month
function GetDaysInMonth(month, year)
    local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

    -- Check for leap year
    if month == 2 then
        if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
            return 29
        end
    end

    return days[month]
end

-- Get the day of week for the first day of the month (0 = Sunday, 6 = Saturday)
function GetFirstDayOfWeek(month, year)
    local t = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
    if month < 3 then
        year = year - 1
    end
    return (year + math.floor(year/4) - math.floor(year/100) + math.floor(year/400) + t[month] + 1) % 7
end

-- Get day number for a specific cell (0-41)
function GetDay(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)

    -- Calculate the day number
    local dayNum = index - firstDayOfWeek + 1

    if dayNum < 1 then
        -- Previous month
        local prevMonth = currentMonth - 1
        local prevYear = currentYear
        if prevMonth < 1 then
            prevMonth = 12
            prevYear = prevYear - 1
        end
        local prevMonthDays = GetDaysInMonth(prevMonth, prevYear)
        return prevMonthDays + dayNum
    elseif dayNum > daysInMonth then
        -- Next month
        return dayNum - daysInMonth
    else
        -- Current month
        return dayNum
    end
end

-- Check if day is in current month
function IsInCurrentMonth(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
    local dayNum = index - firstDayOfWeek + 1

    if dayNum >= 1 and dayNum <= daysInMonth then
        return 1
    else
        return 0
    end
end

-- Check if day is today
function IsToday(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
    local dayNum = index - firstDayOfWeek + 1

    -- Check if this cell shows today's date and we're in current month
    if dayNum >= 1 and dayNum <= daysInMonth then
        if dayNum == todayDay and
           currentMonth == tonumber(os.date('%m')) and
           currentYear == tonumber(os.date('%Y')) then
            return 1
        end
    end

    return 0
end

-- Move to previous month
function PrevMonth()
    currentMonth = currentMonth - 1
    if currentMonth < 1 then
        currentMonth = 12
        currentYear = currentYear - 1
    end
end

-- Move to next month
function NextMonth()
    currentMonth = currentMonth + 1
    if currentMonth > 12 then
        currentMonth = 1
        currentYear = currentYear + 1
    end
end

-- Reset to current month
function GoToToday()
    currentMonth = tonumber(os.date('%m'))
    currentYear = tonumber(os.date('%Y'))
    todayDay = tonumber(os.date('%d'))
    -- Also set selected date to today
    selectedDate = os.date("%Y-%m-%d")
end

-- Get current month name and year
function GetMonthYearString()
    if not currentMonth or not currentYear then
        Initialize()
    end

    local monthNames = {"January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December"}
    return monthNames[currentMonth] .. " " .. currentYear
end

-- Get the color for a day cell
function GetDayColor(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    -- Check if today - return dark text for circle background
    if IsToday(index) == 1 then
        return "20,20,20,255"  -- Dark text on cyan circle
    end

    -- Check if selected date (and not today) - return black text for white circle
    if selectedDate then
        local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
        local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
        local dayNum = index - firstDayOfWeek + 1

        local cellDate
        if dayNum >= 1 and dayNum <= daysInMonth then
            cellDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, dayNum)
        elseif dayNum < 1 then
            local prevMonth = currentMonth - 1
            local prevYear = currentYear
            if prevMonth < 1 then
                prevMonth = 12
                prevYear = prevYear - 1
            end
            local prevMonthDays = GetDaysInMonth(prevMonth, prevYear)
            local actualDay = prevMonthDays + dayNum
            cellDate = string.format("%04d-%02d-%02d", prevYear, prevMonth, actualDay)
        else
            local nextMonth = currentMonth + 1
            local nextYear = currentYear
            if nextMonth > 12 then
                nextMonth = 1
                nextYear = nextYear + 1
            end
            local actualDay = dayNum - daysInMonth
            cellDate = string.format("%04d-%02d-%02d", nextYear, nextMonth, actualDay)
        end

        if cellDate == selectedDate then
            return "0,0,0,255"  -- Black text on white circle
        end
    end

    -- Check if in current month
    if IsInCurrentMonth(index) == 0 then
        return "80,80,80,150"  -- ColorDayOtherMonth
    end

    -- Default cyan color
    return "0,200,255,255"  -- Cyan for normal days
end

-- Get background circle color (only shows for today)
function GetTodayBG(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    -- If today, return cyan background
    if IsToday(index) == 1 then
        return "0,200,255,255"  -- Cyan circle
    end

    -- Otherwise transparent
    return "0,0,0,0"
end

-- Get background circle color - returns cyan for today, white for selected (not today)
function GetDayBG(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    -- If today, return cyan background
    if IsToday(index) == 1 then
        return "0,200,255,255"  -- Cyan circle
    end

    -- If it's the selected date (and NOT today), return white
    if not selectedDate then
        return "0,0,0,0"
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
    local dayNum = index - firstDayOfWeek + 1

    local cellDate
    if dayNum >= 1 and dayNum <= daysInMonth then
        cellDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, dayNum)
    elseif dayNum < 1 then
        local prevMonth = currentMonth - 1
        local prevYear = currentYear
        if prevMonth < 1 then
            prevMonth = 12
            prevYear = prevYear - 1
        end
        local prevMonthDays = GetDaysInMonth(prevMonth, prevYear)
        local actualDay = prevMonthDays + dayNum
        cellDate = string.format("%04d-%02d-%02d", prevYear, prevMonth, actualDay)
    else
        local nextMonth = currentMonth + 1
        local nextYear = currentYear
        if nextMonth > 12 then
            nextMonth = 1
            nextYear = nextYear + 1
        end
        local actualDay = dayNum - daysInMonth
        cellDate = string.format("%04d-%02d-%02d", nextYear, nextMonth, actualDay)
    end

    -- Return white if selected date
    if cellDate == selectedDate then
        return "255,255,255,255"  -- White circle
    end

    return "0,0,0,0"
end

-- Get background circle color for selected date (white, only if NOT today)
function GetSelectedDateBG(index)
    index = tonumber(index) or 0

    if not currentMonth or not currentYear then
        Initialize()
    end

    -- If it's today, don't show white (today keeps cyan)
    if IsToday(index) == 1 then
        return "0,0,0,0"  -- Transparent
    end

    -- Check if this date matches selected date
    if not selectedDate then
        return "0,0,0,0"
    end

    local daysInMonth = GetDaysInMonth(currentMonth, currentYear)
    local firstDayOfWeek = GetFirstDayOfWeek(currentMonth, currentYear)
    local dayNum = index - firstDayOfWeek + 1

    local cellDate
    if dayNum >= 1 and dayNum <= daysInMonth then
        cellDate = string.format("%04d-%02d-%02d", currentYear, currentMonth, dayNum)
    elseif dayNum < 1 then
        local prevMonth = currentMonth - 1
        local prevYear = currentYear
        if prevMonth < 1 then
            prevMonth = 12
            prevYear = prevYear - 1
        end
        local prevMonthDays = GetDaysInMonth(prevMonth, prevYear)
        local actualDay = prevMonthDays + dayNum
        cellDate = string.format("%04d-%02d-%02d", prevYear, prevMonth, actualDay)
    else
        local nextMonth = currentMonth + 1
        local nextYear = currentYear
        if nextMonth > 12 then
            nextMonth = 1
            nextYear = nextYear + 1
        end
        local actualDay = dayNum - daysInMonth
        cellDate = string.format("%04d-%02d-%02d", nextYear, nextMonth, actualDay)
    end

    -- Return white if selected date
    if cellDate == selectedDate then
        print('White circle for ' .. cellDate .. ' (selected: ' .. selectedDate .. ')')
        return "255,255,255,255"  -- White circle
    end

    return "0,0,0,0"
end

-- Parse ICS datetime format to readable format
-- Input: icsDateTime string (YYYYMMDDTHHMMSSZ or YYYYMMDD)
-- Output: "Oct 16, 12:30 PM" or "Oct 16" (all day event)
function FormatEventDateTime(icsDateTime)
    if not icsDateTime or icsDateTime == "" then
        return ""
    end

    -- Remove any TZID prefix (e.g., "TZID=Asia/Kolkata:")
    icsDateTime = string.gsub(icsDateTime, "^[^:]*:", "")

    -- Extract date parts: YYYYMMDD
    local year = string.sub(icsDateTime, 1, 4)
    local month = tonumber(string.sub(icsDateTime, 5, 6))
    local day = tonumber(string.sub(icsDateTime, 7, 8))

    local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

    local dateStr = monthNames[month] .. " " .. day

    -- Check if there's a time component (T means time follows)
    if string.find(icsDateTime, "T") then
        local hour = tonumber(string.sub(icsDateTime, 10, 11))
        local minute = string.sub(icsDateTime, 12, 13)

        -- Convert to 12-hour format
        local ampm = "AM"
        if hour >= 12 then
            ampm = "PM"
            if hour > 12 then
                hour = hour - 12
            end
        end
        if hour == 0 then
            hour = 12
        end

        return dateStr .. ", " .. hour .. ":" .. minute .. " " .. ampm
    else
        -- All-day event
        return dateStr
    end
end

-- ICS parsing helpers (append to Calendar.lua)

-- Unfold lines per RFC5545: replace CRLF + SP/TAB or LF + SP/TAB with empty
local function unfold(ics)
  if not ics then return '' end
  -- handle both CRLF and LF
  ics = ics:gsub('\r\n[ \t]', ''):gsub('\n[ \t]', '')
  return ics
end

-- Parse DTSTART string into a comparable string (keeps Z if present)
local function normalize_dt(dt)
  -- dt examples: 20241001T123000Z or 20240104T000000Z or 20240104 (dates)
  if not dt then return '' end
  -- Remove any non-digits except T and Z
  dt = dt:match('([0-9T]+Z?)') or dt
  return dt
end

-- Parse ICS content and return array of {dt=..., title=...}
local function parse_ics_content(ics)
  local events = {}
  if not ics or ics == '' then return events end
  local s = unfold(ics)

  for vevent in s:gmatch('BEGIN:VEVENT(.-)END:VEVENT') do
    -- capture DTSTART (with optional params) and SUMMARY (first line after unfolding)
    local dt = vevent:match('DTSTART[^:]*:([^\r\n]+)') or vevent:match('DTSTART:([^\r\n]+)')
    local summary = vevent:match('SUMMARY:([^\r\n]*)') or ''
    dt = normalize_dt(dt)
    -- trim whitespace
    summary = summary:gsub('^%s+',''):gsub('%s+$','')
    if dt ~= '' and summary ~= '' then
      table.insert(events, { dt = dt, title = summary })
    end
  end

  -- sort by dt (lexical works for YYYYMMDDTHHMMSSZ formats)
  table.sort(events, function(a,b) return a.dt < b.dt end)
  return events
end

-- Cache parsed events (to avoid re-parsing too often). Will be refreshed when requested.
local _cached_events = nil
local _cached_ics = nil

-- Public: get parsed events (up to maxEvents). Reads the WebParser measure "MeasureEventParser".
function GetParsedEvents(maxEvents)
  maxEvents = tonumber(maxEvents) or 5
  local m = SKIN:GetMeasure('MeasureEventParser')
  if not m then
    return {}
  end

  -- use GetStringValue if available, otherwise GetValue (compat)
  local ics = nil
  if m.GetStringValue then
    ics = m:GetStringValue()
  elseif m.GetString then
    ics = m:GetString()
  else
    -- fallback to numeric value (unlikely)
    ics = tostring(m:GetValue())
  end

  if ics ~= _cached_ics then
    _cached_ics = ics
    _cached_events = parse_ics_content(ics)
  end

  if not _cached_events then return {} end
  local out = {}
  for i=1, math.min(maxEvents, #_cached_events) do
    out[#out+1] = _cached_events[i]
  end
  return out
end

-- Public: return a single event field string (for meters)
-- field = 'dt' or 'title'
function GetEventField(index, field)
  index = tonumber(index) or 1
  field = field or 'title'
  local evs = GetParsedEvents(10) -- parse up to 10 for speed
  if evs[index] then
    return evs[index][field] or ''
  end
  return ''
end

-- Convenience functions to be used from meters:
-- [ &MeasureCalendarScript:GetEventTitle(1) ]  -> event 1 title
-- [ &MeasureCalendarScript:GetEventDate(1) ]   -> event 1 date string (DTSTART raw)
function GetEventTitle(index)
  return GetEventField(index, 'title')
end

function GetEventDate(index)
  return GetEventField(index, 'dt')
end

-- Also expose a combined newline-separated string of upcoming events:
function GetUpcomingEventsString(maxEvents)
  maxEvents = tonumber(maxEvents) or 5
  local evs = GetParsedEvents(maxEvents)
  local lines = {}
  for i,ev in ipairs(evs) do
    lines[#lines+1] = ev.dt .. ' | ' .. ev.title
  end
  return table.concat(lines, '\n')
end

-- ===============================================
-- TODAY EVENTS FUNCTIONS
-- ===============================================

-- Check if a today event exists
function HasTodayEvent(index)
  index = tonumber(index) or 1
  local selected = GetSelectedDate()
  local result = GetParsedResultJson(selected)
  if not result or not result.todayEvents then
    return 0
  end
  if result.todayEvents[index] then
    return 1
  else
    return 0
  end
end

-- Get header for selected date events section
function GetSelectedDateEventsHeader()
  local selected = GetSelectedDate()
  local today = os.date("%Y-%m-%d")

  if selected == today then
    return "TODAY EVENTS"
  else
    return selected .. " EVENTS"
  end
end

-- Get today event date (time text) - actually for selected date
function GetTodayEventDate(index)
  index = tonumber(index) or 1
  local selected = GetSelectedDate()
  local result = GetParsedResultJson(selected)
  if not result or not result.todayEvents then
    return ""
  end
  local event = result.todayEvents[index]
  if event then
    return event.timeText or ""
  else
    return ""
  end
end

-- Get today event title - actually for selected date
function GetTodayEventTitle(index)
  index = tonumber(index) or 1
  local selected = GetSelectedDate()
  local result = GetParsedResultJson(selected)
  if not result or not result.todayEvents then
    return ""
  end
  local event = result.todayEvents[index]
  if event then
    return event.summary or ""
  else
    return ""
  end
end

-- ===============================================
-- UPCOMING EVENTS FUNCTIONS (excluding today)
-- ===============================================

-- Check if an upcoming event exists
function HasUpcomingEvent(index)
  index = tonumber(index) or 1
  local result = GetParsedResultJson()
  if not result or not result.upcomingEvents then
    return 0
  end
  if result.upcomingEvents[index] then
    return 1
  else
    return 0
  end
end

-- Get upcoming event date with full info (date + time/all day)
function GetUpcomingEventDate(index)
  index = tonumber(index) or 1
  local result = GetParsedResultJson()
  if not result or not result.upcomingEvents then
    return ""
  end
  local event = result.upcomingEvents[index]
  if event then
    -- Return format: "YYYY-MM-DD, HH:MM - HH:MM" or "YYYY-MM-DD, All day"
    local dateStr = event.dtStartDate or ""
    local timeStr = event.timeText or "All day"
    if dateStr ~= "" then
      return dateStr .. ", " .. timeStr
    else
      return timeStr
    end
  else
    return ""
  end
end

-- Get upcoming event title
function GetUpcomingEventTitle(index)
  index = tonumber(index) or 1
  local result = GetParsedResultJson()
  if not result or not result.upcomingEvents then
    return ""
  end
  local event = result.upcomingEvents[index]
  if event then
    return event.summary or ""
  else
    return ""
  end
end

-- ===============================================
-- PARSER FUNCTIONS (from Parser.lua)
-- ===============================================

local function trim(s)
  if not s then return s end
  return s:match("^%s*(.-)%s*$")
end

-- Convert UTC time to IST and track if date changed
-- Returns: time_string, date_offset (0 = same day, 1 = next day, -1 = prev day)
local function convertUtcToIst(time)
  if not time then return time, 0 end
  local h, m = time:match("^(%d%d):(%d%d)")
  if not h then return time, 0 end
  h, m = tonumber(h), tonumber(m)
  local total = h * 60 + m + 330 -- +5h30m
  local dateOffset = 0

  if total >= (24 * 60) then
    dateOffset = 1  -- Next day
    total = total % (24 * 60)
  elseif total < 0 then
    dateOffset = -1  -- Previous day
    total = (24 * 60) + total
  end

  local hh = math.floor(total / 60)
  local mm = total % 60
  return string.format("%02d:%02d", hh, mm), dateOffset
end

-- Helper to add days to a date string (YYYY-MM-DD format)
local function addDaysToDate(dateStr, days)
  if not dateStr or days == 0 then return dateStr end
  local y, m, d = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if not y then return dateStr end

  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  d = d + days

  -- Simple date math (good enough for ±1 days)
  if d > 31 then
    d = d - 31
    m = m + 1
    if m > 12 then
      m = 1
      y = y + 1
    end
  elseif d < 1 then
    m = m - 1
    if m < 1 then
      m = 12
      y = y - 1
    end
    d = d + 31
  end

  return string.format("%04d-%02d-%02d", y, m, d)
end

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

-- Format time range and return timeText + dateOffset for start date
-- dateOffset tells us if the local date shifted due to UTC conversion
local function formatTimeRange(start, finish, isAllDay, startIsUtc, endIsUtc)
  if isAllDay then return "All day", 0 end
  local function short(t) return t and t:sub(1, 5) or nil end
  local dateOffset = 0

  if startIsUtc then
    start, dateOffset = convertUtcToIst(start)
  end
  if endIsUtc then
    finish = convertUtcToIst(finish)  -- We only care about dateOffset for start
  end

  local timeText
  if start and finish then
    timeText = short(start) .. " - " .. short(finish)
  elseif start then
    timeText = short(start)
  else
    timeText = nil
  end

  return timeText, dateOffset
end

local function parseIcs(body)
  if not body then return {} end
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

      -- Get timeText and dateOffset (for UTC->IST conversion)
      local timeText, dateOffset = formatTimeRange(
        e._start and e._start.time,
        e._end and e._end.time,
        e.isAllDay,
        e._start and e._start.isUtc,
        e._end and e._end.isUtc
      )
      e.timeText = timeText

      -- Adjust dtStartDate if UTC->IST conversion shifted the date
      if dateOffset ~= 0 and e.dtStartDate then
        e.dtStartDate = addDaysToDate(e.dtStartDate, dateOffset)
      end

      table.insert(events, e)
    end
  end
  return events
end

local function filterEvents(events, today)
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

local function slimEvent(e)
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

local function formatOutput(todayEvents, upcomingEvents, today, limit)
  limit = limit or 5
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
    table.insert(out.todayEvents, slimEvent(e))
  end
  for _, e in ipairs(next) do
    table.insert(out.upcomingEvents, slimEvent(e))
  end
  return out
end

local _cached_parsed_result = nil
local _cached_ics_content = nil
local _cached_date = nil

function GetParsedResultJson(selectedDate)
  -- If no selectedDate argument provided, use today
  if not selectedDate then
    selectedDate = os.date("%Y-%m-%d")
  end

  local icsContent = ""
  if SKIN then
    local measure = SKIN:GetMeasure('MeasureEventParser')
    if measure then
      if measure.GetStringValue then
        icsContent = measure:GetStringValue() or ""
      elseif measure.GetString then
        icsContent = measure:GetString() or ""
      else
        icsContent = tostring(measure:GetValue() or "")
      end
    end
  end

  -- Cache only if ICS content and date match
  if icsContent == _cached_ics_content and _cached_parsed_result and selectedDate == _cached_date then
    return _cached_parsed_result
  end

  if icsContent == "" then
    print('WARNING: No ICS content from MeasureEventParser')
    return nil
  end

  local events = parseIcs(icsContent)
  local todayEvents, upcomingEvents = filterEvents(events, selectedDate)
  local result = formatOutput(todayEvents, upcomingEvents, selectedDate, 5)

  _cached_ics_content = icsContent
  _cached_parsed_result = result
  _cached_date = selectedDate

  return result
end
