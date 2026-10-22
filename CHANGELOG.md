# Changelog

This project is a fork of [Gourav2000/CyberCalender](https://github.com/Gourav2000/CyberCalender).
Everything below is what was added or changed in the fork.

## 6.0

### New
- **Tabs Day / Week / Month** (Day is the default). Arrows move by 1 day / 7 days / 1 month.
- **Day view**
  - "Now" card: current time, time until the next event (or time left in the current one), free time left today, progress bar of the day, total free time of the whole day (top right).
  - Timeline of events with **free windows** ("Free, 1h") between them. The current event is highlighted, past ones are dimmed.
  - Free windows longer than 8 hours are not shown (most likely sleep). Today, free time that has already passed is hidden and the current window starts from "now". Other days show total free time instead of the clock.
- **Week view**: 7 day cards with up to 3 events each and "+N more"; click a card to open that day.
- **Adaptive height**: the panel shrinks in Day and Month when there are few events.
- **Month view**: double-click a day to open it in Day; event dots are centred and coloured per calendar.
- **Always on top** support and a layout meant for a secondary monitor.
- Settings in `[Variables]`: `WeekStart` (0 = Sunday, 1 = Monday; set to Monday), `DayStart` / `DayEnd`, `MinGap`, `MaxFreeGap`.

### Design
- New dark blue palette with one soft accent colour, rounded cards, rounded day cells and a segmented tab control.
- Larger fonts (times, titles, free-time labels) and brighter secondary text for readability.
- All colours are variables in `[Variables]` and are read by the Lua script (no colours hard-coded in Lua any more).

### Fixes and cleanup
- **Recurring events (RRULE) are now expanded** (DAILY, WEEKLY with BYDAY, MONTHLY, YEARLY, INTERVAL, COUNT, UNTIL, EXDATE, moved instances via RECURRENCE-ID). Before, only the first occurrence of a series was shown, so weekly lessons were missing.
- Events that repeat every day are treated as background routines: shown in Day, hidden in Week and Month (`DailyAsRoutine=0` to disable).
- Event times are converted from UTC to your time zone (was hard-coded to IST, +5:30): the Windows time zone, or a fixed `UtcOffsetHours` from `Variables.inc` (useful when the PC time zone differs from the calendar's).
- Events with `TZID` (e.g. `Europe/Moscow`, `Asia/Yekaterinburg`) are converted correctly instead of being shown as written.
- The clock and "today" in the skin use the same time zone as events, so they always agree.
- Multi-day all-day events are shown on every day they cover.
- ICS parsing: escaped characters (`\,` `\;` `\n`), fields with parameters, locations.
- Private calendar links moved out of `Calendar.ini` into the gitignored `@Resources/Variables.inc`.
- `Variables.inc.example` was missing the `[Variables]` header, so Rainmeter ignored the variables (the second calendar could never work). Fixed.
- If the calendar download fails (for example no network right after Windows starts), the skin retries after 20 seconds instead of waiting for the next 5-minute refresh.
- Removed `Debug=1` from WebParser and references to a non-existent meter; the script re-parses ICS only when the downloaded data changes.
- `Calendar.ini` rewritten with `MeterStyle` and a single script call per value instead of ~2800 lines of copy-paste per cell; month cells are now one shape plus one text meter.
- The window is click-through outside the panel (`SolidColor=0,0,0,0`).

### Code and docs
- `Calendar.lua`: shared helpers for settings and date/time, cached month grid dates, removed unused functions.
- README redesigned (hero screenshots, badges, usage and configuration tables) with before/after screenshots in `docs/`.

### Known limitations
- Recurrence rules with a week number ("every first Monday") or `BYMONTHDAY` are not supported.
- The Rainmeter window does not shrink with the panel, only the visible part does (the empty area is transparent and click-through).
