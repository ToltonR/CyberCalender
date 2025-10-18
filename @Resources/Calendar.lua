-- Calendar Grid Generation for Rainmeter
-- ===============================================

function Initialize()
    currentMonth = tonumber(os.date('%m'))
    currentYear = tonumber(os.date('%Y'))
    todayDay = tonumber(os.date('%d'))

    -- Debug: Log the initialization
    print('Calendar initialized: ' .. currentMonth .. '/' .. todayDay .. '/' .. currentYear)
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

-- Get today's events only
function GetTodayEvents()
  local allEvents = GetParsedEvents(50) -- Get more events to filter
  local todayEvents = {}
  local todayDate = os.date("%Y%m%d")

  for _, ev in ipairs(allEvents) do
    local eventDate = string.sub(ev.dt, 1, 8) -- Extract YYYYMMDD
    if eventDate == todayDate then
      table.insert(todayEvents, ev)
    end
  end

  return todayEvents
end

-- Check if a today event exists
function HasTodayEvent(index)
  index = tonumber(index) or 1
  local todayEvents = GetTodayEvents()
  if todayEvents[index] then
    return 1
  else
    return 0
  end
end

-- Get today event date
function GetTodayEventDate(index)
  index = tonumber(index) or 1
  local todayEvents = GetTodayEvents()
  if todayEvents[index] then
    return FormatEventDateTime(todayEvents[index].dt)
  else
    return ""
  end
end

-- Get today event title
function GetTodayEventTitle(index)
  index = tonumber(index) or 1
  local todayEvents = GetTodayEvents()
  if todayEvents[index] then
    return todayEvents[index].title
  else
    return ""
  end
end

-- ===============================================
-- UPCOMING EVENTS FUNCTIONS (excluding today)
-- ===============================================

-- Get upcoming events (excluding today's events)
function GetUpcomingEvents(maxEvents)
  maxEvents = tonumber(maxEvents) or 5
  local allEvents = GetParsedEvents(50)
  local upcomingEvents = {}
  local todayDate = os.date("%Y%m%d")

  for _, ev in ipairs(allEvents) do
    local eventDate = string.sub(ev.dt, 1, 8) -- Extract YYYYMMDD
    if eventDate > todayDate then
      table.insert(upcomingEvents, ev)
      if #upcomingEvents >= maxEvents then
        break
      end
    end
  end

  return upcomingEvents
end

-- Check if an upcoming event exists
function HasUpcomingEvent(index)
  index = tonumber(index) or 1
  local upcomingEvents = GetUpcomingEvents(10)
  if upcomingEvents[index] then
    return 1
  else
    return 0
  end
end

-- Get upcoming event date
function GetUpcomingEventDate(index)
  index = tonumber(index) or 1
  local upcomingEvents = GetUpcomingEvents(10)
  if upcomingEvents[index] then
    return FormatEventDateTime(upcomingEvents[index].dt)
  else
    return ""
  end
end

-- Get upcoming event title
function GetUpcomingEventTitle(index)
  index = tonumber(index) or 1
  local upcomingEvents = GetUpcomingEvents(10)
  if upcomingEvents[index] then
    return upcomingEvents[index].title
  else
    return ""
  end
end
