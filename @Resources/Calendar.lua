-- Календарь для Rainmeter: вкладки Month / Week / Day.
-- Цвета берутся из [Variables] в Calendar.ini, палитра меняется в одном месте.
-- Все функции вызываются из .ini через [&MeasureCalendarScript:Имя(аргументы)],
-- поэтому аргументы везде числовые (без кавычек) и сразу приводятся через tonumber.

local VIEW_MONTH, VIEW_WEEK, VIEW_DAY, VIEW_PICKER = 0, 1, 2, 3
local view = VIEW_DAY   -- вкладка по умолчанию
local currentMonth, currentYear   -- какой месяц показан в сетке
local selectedDate = nil          -- "YYYY-MM-DD", если пользователь выбрал дату (nil = сегодня)
local pickerOpen, pickerYear = false, nil

local MONTHS = {"January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"}
local MONTHS_SHORT = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
local DOW_SHORT = {"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"}
local DOW_LONG = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}

local CLEAR = "0,0,0,0"

local function color(name)
    return SKIN:GetVariable(name, "255,255,255,255")
end

-- 0 = неделя с воскресенья, 1 = с понедельника (переменная WeekStart в .ini)
local function weekStart()
    return tonumber(SKIN:GetVariable("WeekStart", "0")) or 0
end

-- ===============================================
-- ДАТЫ (строки "YYYY-MM-DD"; арифметика через os.time на полдень, чтобы не ловить переход на летнее время)
-- ===============================================

local function fmtDate(y, m, d)
    return string.format("%04d-%02d-%02d", y, m, d)
end

local function today()
    return os.date("%Y-%m-%d")
end

local function parts(s)
    local y, m, d = s:match("^(%d+)-(%d+)-(%d+)$")
    return tonumber(y), tonumber(m), tonumber(d)
end

local function epoch(s)
    local y, m, d = parts(s)
    return os.time{year = y, month = m, day = d, hour = 12}
end

local function addDays(s, n)
    return os.date("%Y-%m-%d", epoch(s) + n * 86400)
end

-- день недели: 0 = воскресенье
local function dow(s)
    return tonumber(os.date("%w", epoch(s)))
end

local function focus()
    return selectedDate or today()
end

local function weekFirst(date)
    return addDays(date, -((dow(date) - weekStart()) % 7))
end

local function shortDate(s)
    local _, m, d = parts(s)
    return MONTHS_SHORT[m] .. " " .. d
end

-- дата, которую показывает ячейка сетки (0-41)
local function cellDate(index)
    local first = fmtDate(currentYear, currentMonth, 1)
    return addDays(first, (tonumber(index) or 0) - (dow(first) - weekStart()) % 7)
end

-- ===============================================
-- СОБЫТИЯ (ICS из двух календарей)
-- ===============================================

local events = {}
local rawA, rawB = nil, nil
local dayCache, upCache, slotCache = {}, {}, {}

local function readMeasure(name)
    local m = SKIN:GetMeasure(name)
    if not m then return "" end
    return (m.GetStringValue and m:GetStringValue()) or ""
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function unescape(s)
    return (s:gsub("\\n", " "):gsub("\\N", " "):gsub("\\,", ","):gsub("\\;", ";"):gsub("\\\\", "\\"))
end

-- UTC-время из ICS -> локальные дата и "HH:MM" (смещение берём из системы, а не зашитое)
local function utcToLocal(date, time)
    local y, m, d = parts(date)
    local hh, mi, ss = time:match("^(%d+):(%d+):(%d+)$")
    local asLocal = os.time{year = y, month = m, day = d, hour = tonumber(hh), min = tonumber(mi), sec = tonumber(ss)}
    local offset = os.time(os.date("*t", asLocal)) - os.time(os.date("!*t", asLocal))
    local t = os.date("*t", asLocal + offset)
    return fmtDate(t.year, t.month, t.day), string.format("%02d:%02d", t.hour, t.min)
end

-- "20251021" (весь день) | "20251021T123000Z" (UTC) | "20251021T123000" (локальное)
local function parseDt(raw)
    if not raw then return nil end
    raw = trim(raw)
    local y, m, d = raw:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if y then
        return {date = y .. "-" .. m .. "-" .. d, allDay = true}
    end
    local y2, m2, d2, hh, mi, ss, z = raw:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)(Z?)$")
    if not y2 then return nil end
    local date = y2 .. "-" .. m2 .. "-" .. d2
    if z == "Z" then
        local ld, lt = utcToLocal(date, hh .. ":" .. mi .. ":" .. ss)
        return {date = ld, time = lt}
    end
    return {date = date, time = hh .. ":" .. mi}
end

local function parseIcs(body, source)
    local out = {}
    if not body or body == "" then return out end
    -- нормализуем переводы строк и склеиваем «сложенные» строки (RFC 5545)
    body = body:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n[ \t]", "")
    for block in body:gmatch("BEGIN:VEVENT(.-)END:VEVENT") do
        local function field(key)
            return block:match("\n" .. key .. "[^:\n]*:([^\n]*)")
        end
        local s = parseDt(field("DTSTART"))
        if s then
            local e = parseDt(field("DTEND"))
            local ev = {
                source = source,
                title = trim(unescape(field("SUMMARY") or "")),
                location = trim(unescape(field("LOCATION") or "")),
                allDay = s.allDay or false,
                startDate = s.date,
                startTime = s.time,
                endTime = e and e.time,
            }
            if ev.title == "" then ev.title = "(No title)" end
            if ev.allDay then
                -- DTEND у событий на весь день не включается в диапазон
                ev.endDate = (e and e.date and e.date > s.date) and e.date or addDays(s.date, 1)
            end
            ev.key = (ev.allDay and "0" or "1") .. (ev.startTime or "")
            out[#out + 1] = ev
        end
    end
    return out
end

local function sortEvents(a, b)
    if a.startDate ~= b.startDate then return a.startDate < b.startDate end
    if a.key ~= b.key then return a.key < b.key end
    return a.title < b.title
end

-- перечитываем ICS только если данные от WebParser изменились
local function reload()
    local a, b = readMeasure("MeasureEventParser"), readMeasure("MeasureEventParser2")
    if a == rawA and b == rawB then return end
    rawA, rawB = a, b
    events = {}
    for _, e in ipairs(parseIcs(a, "1")) do events[#events + 1] = e end
    for _, e in ipairs(parseIcs(b, "2")) do events[#events + 1] = e end
    table.sort(events, sortEvents)
    dayCache, upCache, slotCache = {}, {}, {}
end

local function eventsOn(date)
    local cached = dayCache[date]
    if cached then return cached end
    local out = {}
    for _, e in ipairs(events) do
        if e.startDate > date then break end   -- список отсортирован по дате начала
        if e.allDay then
            if date < e.endDate then out[#out + 1] = e end
        elseif e.startDate == date then
            out[#out + 1] = e
        end
    end
    table.sort(out, function(x, y)
        if x.key ~= y.key then return x.key < y.key end
        return x.title < y.title
    end)
    dayCache[date] = out
    return out
end

local function upcoming(date, limit)
    local cached = upCache[date]
    if cached then return cached end
    local out = {}
    for _, e in ipairs(events) do
        if e.startDate > date then
            out[#out + 1] = e
            if #out >= limit then break end
        end
    end
    upCache[date] = out
    return out
end

local function sourceColor(src)
    return color(src == "2" and "ColorTag2" or "ColorTag1")
end

local function timeText(e)
    if e.allDay then return "All day" end
    if e.endTime and e.endTime ~= e.startTime then
        return e.startTime .. " - " .. e.endTime
    end
    return e.startTime or ""
end

local function hasSource(date, src)
    for _, e in ipairs(eventsOn(date)) do
        if e.source == src then return true end
    end
    return false
end

-- списки для Month: 1 = события выбранного дня, 2 = ближайшие после него
local function getList(list)
    if list == 2 then return upcoming(focus(), 3) end
    return eventsOn(focus())
end
local LIST_VIEW = {[1] = VIEW_MONTH, [2] = VIEW_MONTH}

-- ===============================================
-- ЖИЗНЕННЫЙ ЦИКЛ И НАВИГАЦИЯ
-- ===============================================

function Initialize()
    currentMonth = tonumber(os.date("%m"))
    currentYear = tonumber(os.date("%Y"))
end

function Update()
    reload()
    return 1
end

function SetView(v)
    v = tonumber(v) or VIEW_MONTH
    -- уходим из месяца, который не текущий, и дата не выбрана: берём 1-е число показанного месяца
    if v ~= VIEW_MONTH and view == VIEW_MONTH and not selectedDate then
        if currentMonth ~= tonumber(os.date("%m")) or currentYear ~= tonumber(os.date("%Y")) then
            selectedDate = fmtDate(currentYear, currentMonth, 1)
        end
    end
    if v == VIEW_MONTH then
        currentYear, currentMonth = parts(focus())
    end
    view = v
    pickerOpen = false
end

local function shift(dir)
    if view == VIEW_MONTH then
        currentMonth = currentMonth + dir
        if currentMonth < 1 then currentMonth = 12; currentYear = currentYear - 1 end
        if currentMonth > 12 then currentMonth = 1; currentYear = currentYear + 1 end
    elseif view == VIEW_WEEK then
        selectedDate = addDays(focus(), 7 * dir)
    else
        selectedDate = addDays(focus(), dir)
    end
end

function PrevPeriod() shift(-1) end
function NextPeriod() shift(1) end

function GoToToday()
    selectedDate = nil
    currentMonth = tonumber(os.date("%m"))
    currentYear = tonumber(os.date("%Y"))
    pickerOpen = false
end

-- клик по ячейке месяца (index 0-41); серые даты соседних месяцев переключают сетку
function SetSelectedDate(index)
    selectedDate = cellDate(index)
    currentYear, currentMonth = parts(selectedDate)
end

-- клик по строке недели -> открыть этот день во вкладке Day
function OpenWeekDay(d)
    selectedDate = addDays(weekFirst(focus()), tonumber(d) or 0)
    SetView(VIEW_DAY)
end

-- 1 = элемент скрыт. v: 0 Month, 1 Week, 2 Day, 3 пикер месяца
function Hid(v)
    v = tonumber(v)
    if v == VIEW_PICKER then return pickerOpen and 0 or 1 end
    return (view == v) and 0 or 1
end

-- ===============================================
-- ЗАГОЛОВОК И ВКЛАДКИ
-- ===============================================

function GetTitle()
    if view == VIEW_MONTH then
        return MONTHS[currentMonth] .. " " .. currentYear
    elseif view == VIEW_WEEK then
        local a = weekFirst(focus())
        local ya, ma, da = parts(a)
        local yb, mb, db = parts(addDays(a, 6))
        if ma == mb then
            return MONTHS_SHORT[ma] .. " " .. da .. " - " .. db .. ", " .. yb
        elseif ya == yb then
            return MONTHS_SHORT[ma] .. " " .. da .. " - " .. MONTHS_SHORT[mb] .. " " .. db .. ", " .. yb
        end
        return MONTHS_SHORT[ma] .. " " .. da .. ", " .. ya .. " - " .. MONTHS_SHORT[mb] .. " " .. db .. ", " .. yb
    end
    local f = focus()
    local _, m, d = parts(f)
    return DOW_LONG[dow(f) + 1] .. ", " .. MONTHS_SHORT[m] .. " " .. d
end

local function plural(n)
    if n == 0 then return "No events" end
    return n .. (n == 1 and " event" or " events")
end

function GetSubtitle()
    if view == VIEW_MONTH then
        local t = today()
        local y, m, d = parts(t)
        return DOW_LONG[dow(t) + 1] .. ", " .. MONTHS[m] .. " " .. d .. ", " .. y
    elseif view == VIEW_WEEK then
        local first, n = weekFirst(focus()), 0
        for i = 0, 6 do n = n + #eventsOn(addDays(first, i)) end
        return plural(n) .. " this week"
    end
    local f = focus()
    local diff = math.floor((epoch(f) - epoch(today())) / 86400 + 0.5)
    local rel
    if diff == 0 then rel = "Today"
    elseif diff == 1 then rel = "Tomorrow"
    elseif diff == -1 then rel = "Yesterday"
    elseif diff > 1 then rel = "In " .. diff .. " days"
    else rel = -diff .. " days ago" end
    return rel .. ", " .. plural(#eventsOn(f))
end

function TabBG(i)
    return (tonumber(i) == view) and color("ColorAccent") or CLEAR
end

function TabText(i)
    return (tonumber(i) == view) and color("ColorOnAccent") or color("ColorTextSub")
end

-- ===============================================
-- MONTH: СЕТКА
-- ===============================================

function GetDowLabel(i)
    return DOW_SHORT[(weekStart() + tonumber(i)) % 7 + 1]
end

function GetDay(index)
    local _, _, d = parts(cellDate(index))
    return d
end

local function isSelectedOnly(date)
    return selectedDate == date and date ~= today()
end

function GetDayBG(index)
    local date = cellDate(index)
    if date == today() then return color("ColorAccent") end
    if isSelectedOnly(date) then return color("ColorAccentSoft") end
    return CLEAR
end

function GetDayStroke(index)
    if isSelectedOnly(cellDate(index)) then return color("ColorAccent") end
    return CLEAR
end

function GetDayColor(index)
    local date = cellDate(index)
    if date == today() then return color("ColorOnAccent") end
    if isSelectedOnly(date) then return color("ColorAccent") end
    local _, m = parts(date)
    if m == currentMonth then return color("ColorText") end
    return color("ColorDim")
end

-- точки событий под числом: slot 0 = одна по центру, 1/2 = две рядом (если есть оба календаря)
function GetDotColor(index, slot)
    local date = cellDate(index)
    local a, b = hasSource(date, "1"), hasSource(date, "2")
    if not (a or b) then return CLEAR end
    local onToday = (date == today())
    local c1 = onToday and color("ColorOnAccent") or sourceColor("1")
    local c2 = onToday and color("ColorOnAccent") or sourceColor("2")
    slot = tonumber(slot)
    if a and b then
        if slot == 1 then return c1 end
        if slot == 2 then return c2 end
        return CLEAR
    end
    if slot == 0 then return a and c1 or c2 end
    return CLEAR
end

-- ===============================================
-- ПИКЕР МЕСЯЦА
-- ===============================================

function ToggleMonthPicker()
    pickerOpen = not pickerOpen
    if pickerOpen then
        if view ~= VIEW_MONTH then
            currentYear, currentMonth = parts(focus())
        end
        pickerYear = currentYear
    end
end

function ClosePicker() pickerOpen = false end

function GetPickerYear()
    return pickerYear or currentYear or tonumber(os.date("%Y"))
end

function PickerYearUp() pickerYear = GetPickerYear() + 1 end
function PickerYearDown() pickerYear = GetPickerYear() - 1 end

function GetMonthAbbrev(i)
    return (MONTHS_SHORT[tonumber(i)] or ""):upper()
end

local function isCurrentPickerMonth(i)
    return tonumber(i) == currentMonth and GetPickerYear() == currentYear
end

function MonthBtnBG(i)
    return isCurrentPickerMonth(i) and color("ColorAccent") or color("ColorSurface2")
end

function MonthBtnText(i)
    return isCurrentPickerMonth(i) and color("ColorOnAccent") or color("ColorText")
end

function SelectMonth(i)
    currentMonth = tonumber(i) or 1
    currentYear = GetPickerYear()
    -- в Month выбор сбрасывается; в Week/Day переходим на 1-е число выбранного месяца
    if view == VIEW_MONTH then
        selectedDate = nil
    else
        selectedDate = fmtDate(currentYear, currentMonth, 1)
    end
    pickerOpen = false
end

-- ===============================================
-- СПИСКИ СОБЫТИЙ (Month: списки 1 и 2, Day: список 3)
-- ===============================================

function HidEv(list, i)
    list = tonumber(list)
    if view ~= LIST_VIEW[list] then return 1 end
    return getList(list)[tonumber(i)] and 0 or 1
end

function EvTime(list, i)
    list = tonumber(list)
    local e = getList(list)[tonumber(i)]
    if not e then return "" end
    if list == 2 then return shortDate(e.startDate) .. ", " .. (e.allDay and "All day" or e.startTime) end
    return timeText(e)
end

function EvTitle(list, i)
    local e = getList(tonumber(list))[tonumber(i)]
    return e and e.title or ""
end

function EvLoc(list, i)
    local e = getList(tonumber(list))[tonumber(i)]
    return e and e.location or ""
end

function EvDot(list, i)
    local e = getList(tonumber(list))[tonumber(i)]
    return e and sourceColor(e.source) or CLEAR
end

-- шапка карточки выбранного дня (Month)
function GetSelHeader()
    local f = focus()
    if f == today() then return "Today" end
    local _, m, d = parts(f)
    return DOW_SHORT[dow(f) + 1] .. ", " .. MONTHS_SHORT[m] .. " " .. d
end

function GetSelCount()
    return plural(#eventsOn(focus()))
end

-- ===============================================
-- DAY: баннер «сейчас» + лента из событий и окон свободного времени
-- ===============================================

local DAY_SLOTS = 8

local function toMin(t)
    return tonumber(t:sub(1, 2)) * 60 + tonumber(t:sub(4, 5))
end

local function fmtMin(m)
    return string.format("%02d:%02d", math.floor(m / 60), m % 60)
end

local function durText(m)
    local h, mm = math.floor(m / 60), m % 60
    if h > 0 and mm > 0 then return h .. "h " .. mm .. "m" end
    if h > 0 then return h .. "h" end
    return mm .. "m"
end

local function nowMin()
    return tonumber(os.date("%H")) * 60 + tonumber(os.date("%M"))
end

local function dayWindow()   -- рабочее окно, в котором ищем свободное время (минуты от 00:00)
    local s = (tonumber(SKIN:GetVariable("DayStart", "8")) or 8) * 60
    local e = (tonumber(SKIN:GetVariable("DayEnd", "22")) or 22) * 60
    return s, e
end

local function minGap()
    return tonumber(SKIN:GetVariable("MinGap", "30")) or 30
end

-- окна длиннее этого (минуты) не показываем: скорее всего это сон или пустой день
local function maxGap()
    return tonumber(SKIN:GetVariable("MaxFreeGap", "480")) or 480
end

-- слоты дня по порядку: события на весь день, затем timed-события и свободные окна между ними
-- {kind="ev", e=событие, s, en} | {kind="gap", s, en}; пересекающиеся события учитываются как одно занятое время
local function daySlots(date)
    if slotCache[date] then return slotCache[date] end
    local ws, we = dayWindow()
    local gapMin, gapMax = minGap(), maxGap()
    local slots, timed = {}, {}
    local function addGap(from, to)
        local len = to - from
        if len >= gapMin and len <= gapMax then
            slots[#slots + 1] = {kind = "gap", s = from, en = to}
        end
    end
    for _, e in ipairs(eventsOn(date)) do
        if e.allDay then
            slots[#slots + 1] = {kind = "ev", e = e}
        else
            local s = toMin(e.startTime)
            local en = e.endTime and toMin(e.endTime) or s
            if en <= s then en = (e.endTime and 1440 or s) end   -- ушло за полночь / нет конца
            timed[#timed + 1] = {kind = "ev", e = e, s = s, en = en}
        end
    end
    table.sort(timed, function(a, b) return a.s < b.s end)
    local cursor = ws
    for _, t in ipairs(timed) do
        addGap(cursor, math.min(t.s, we))
        slots[#slots + 1] = t
        if t.en > cursor then cursor = t.en end
    end
    addGap(cursor, we)
    slotCache[date] = slots
    return slots
end

local function slotAt(k)
    return daySlots(focus())[tonumber(k)]
end

-- "past" | "now" | "future": только для сегодняшнего дня и событий со временем
local function slotState(sl)
    if focus() ~= today() or not sl.s then return "future" end
    local n = nowMin()
    if sl.en <= n then return "past" end
    if sl.s <= n then return "now" end
    return "future"
end

function HidSlot(k)
    if view ~= VIEW_DAY then return 1 end
    return slotAt(k) and 0 or 1
end

function SlotFill(k)
    local sl = slotAt(k)
    if sl and sl.kind == "gap" then return color("ColorFreeFill") end
    return color("ColorSurface")
end

function SlotStroke(k)
    local sl = slotAt(k)
    if not sl then return CLEAR end
    if slotState(sl) == "now" then return color("ColorAccent") end
    if sl.kind == "gap" then return color("ColorAccentSoft") end
    return color("ColorBorder")
end

function SlotBar(k)
    local sl = slotAt(k)
    if not sl then return CLEAR end
    if sl.kind == "gap" then return color("ColorAccentLine") end
    return sourceColor(sl.e.source)
end

function SlotTime(k)
    local sl = slotAt(k)
    if not sl then return "" end
    if sl.kind == "gap" then return fmtMin(sl.s) .. " - " .. fmtMin(sl.en) end
    return timeText(sl.e)
end

function SlotTitle(k)
    local sl = slotAt(k)
    if not sl then return "" end
    if sl.kind == "gap" then return "Free, " .. durText(sl.en - sl.s) end
    return sl.e.title
end

function SlotLoc(k)
    local sl = slotAt(k)
    return (sl and sl.kind == "ev") and sl.e.location or ""
end

function SlotTitleColor(k)
    local sl = slotAt(k)
    if not sl then return color("ColorText") end
    if sl.kind == "gap" then return color("ColorAccent") end
    if slotState(sl) == "past" then return color("ColorDim") end
    return color("ColorText")
end

function HidMore()
    if view == VIEW_DAY and #daySlots(focus()) > DAY_SLOTS then return 0 end
    return 1
end

function DayMore()
    local n = #daySlots(focus())
    if view == VIEW_DAY and n > DAY_SLOTS then return "+" .. (n - DAY_SLOTS) .. " more" end
    return ""
end

-- ===============================================
-- АДАПТИВНЫЙ РАЗМЕР: высота окна и положение блоков зависят от числа событий
-- ===============================================

local function selRows() return math.min(3, #eventsOn(focus())) end
local function selH()
    local r = selRows()
    if r == 0 then return 38 end
    return 42 + 22 * r
end
local function upRows() return #upcoming(focus(), 3) end
local function upH()
    local r = upRows()
    if r == 0 then return 0 end
    return 42 + 22 * r
end
local function upY() return 388 + selH() + 8 end

function SelCardH() return selH() end
function UpCardY() return upY() end
function UpCardH() return math.max(1, upH()) end
function UpRowY(k) return upY() + 40 + (tonumber(k) - 1) * 22 end
function HidUp()
    if view ~= VIEW_MONTH or upRows() == 0 then return 1 end
    return 0
end

function PanelH()
    local h
    if view == VIEW_MONTH then
        h = (upRows() > 0 and (upY() + upH()) or (388 + selH())) + 48
    elseif view == VIEW_WEEK then
        h = 660
    else
        local n = math.min(#daySlots(focus()), DAY_SLOTS)
        h = (n == 0) and 250 or (200 + (n - 1) * 51 + 45 + 58)
    end
    if pickerOpen then h = math.max(h, 440) end   -- пикер месяца должен помещаться
    return h
end
function FooterY() return PanelH() - 28 end
function FooterPillY() return PanelH() - 40 end

-- --- Баннер: сегодня = часы + «до следующего события»; другой день = сумма свободного времени
local function freeTotal(date, fromMin)
    local total = 0
    for _, sl in ipairs(daySlots(date)) do
        if sl.kind == "gap" then
            total = total + math.max(0, sl.en - math.max(sl.s, fromMin or 0))
        end
    end
    return total
end

local function nowAndNext()
    local n, cur, nxt = nowMin(), nil, nil
    for _, sl in ipairs(daySlots(focus())) do
        if sl.kind == "ev" and sl.s then
            if sl.s <= n and n < sl.en and not cur then cur = sl end
            if sl.s > n and not nxt then nxt = sl end
        end
    end
    return cur, nxt, n
end

function BannerBig()
    if focus() == today() then return fmtMin(nowMin()) end
    if #eventsOn(focus()) == 0 then return "Free day" end
    return durText(freeTotal(focus()))
end

function BannerSub()
    local left = (focus() == today()) and freeTotal(focus(), nowMin()) or freeTotal(focus())
    if left <= 0 then return "" end
    return durText(left) .. (focus() == today() and " free left" or " free time")
end

function BannerStatus()
    if focus() ~= today() then
        local ws, we = dayWindow()
        return "Free " .. fmtMin(ws) .. " - " .. fmtMin(we)
    end
    local cur, nxt, n = nowAndNext()
    if cur then return "In progress, " .. durText(cur.en - n) .. " left" end
    if nxt then
        if nxt.s - n < 1 then return "Starting now" end
        return "Next in " .. durText(nxt.s - n)
    end
    return "No more events today"
end

function BannerTitle()
    if focus() ~= today() then return plural(#eventsOn(focus())) end
    local cur, nxt = nowAndNext()
    local e = cur or nxt
    if e then return e.e.title end
    return "Enjoy the free time"
end

-- прогресс рабочего окна дня (только сегодня); ширина дорожки 320
function BannerBarW()
    if focus() ~= today() then return 1 end
    local ws, we = dayWindow()
    local p = (nowMin() - ws) / (we - ws)
    return math.max(1, math.min(1, p) * 320)
end

function BannerBarColor()
    return focus() == today() and color("ColorAccent") or CLEAR
end

-- ===============================================
-- WEEK: 7 строк-карточек по 3 строки событий
-- ===============================================

local function weekDate(d)
    return addDays(weekFirst(focus()), tonumber(d) or 0)
end

-- что показать в строке l (1-3) карточки дня d: "ev" + событие | "more" + число | "none" | nil (пусто)
local function weekCell(d, l)
    local list = eventsOn(weekDate(d))
    local n = #list
    if n == 0 then
        if l == 1 then return "none" end
        return nil
    end
    if n > 3 and l == 3 then return "more", n - 2 end
    if list[l] then return "ev", list[l] end
    return nil
end

function HidWeek(d, l)
    if view ~= VIEW_WEEK then return 1 end
    return weekCell(tonumber(d), tonumber(l)) and 0 or 1
end

function WeekDow(d)
    return DOW_SHORT[dow(weekDate(d)) + 1]
end

function WeekNum(d)
    local _, _, day = parts(weekDate(d))
    return day
end

local function weekIsToday(d)
    return weekDate(d) == today()
end

function WeekBlockBG(d)
    return weekIsToday(d) and color("ColorAccent") or color("ColorSurface2")
end

function WeekDowColor(d)
    return weekIsToday(d) and color("ColorOnAccent") or color("ColorTextSub")
end

function WeekNumColor(d)
    return weekIsToday(d) and color("ColorOnAccent") or color("ColorText")
end

function WeekCardStroke(d)
    return weekIsToday(d) and color("ColorAccentLine") or color("ColorBorder")
end

function WeekTime(d, l)
    local kind, e = weekCell(tonumber(d), tonumber(l))
    if kind == "ev" then return timeText(e) end
    return ""
end

function WeekTitle(d, l)
    local kind, e = weekCell(tonumber(d), tonumber(l))
    if kind == "ev" then return e.title end
    if kind == "more" then return "+" .. e .. " more" end
    if kind == "none" then return "No events" end
    return ""
end

function WeekTitleColor(d, l)
    local kind = weekCell(tonumber(d), tonumber(l))
    if kind == "ev" then return color("ColorText") end
    return color("ColorDim")
end

function WeekDot(d, l)
    local kind, e = weekCell(tonumber(d), tonumber(l))
    if kind == "ev" then return sourceColor(e.source) end
    return CLEAR
end
