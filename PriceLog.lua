-- Price Log: records prices from YOUR OWN auction house scans and searches into SavedVariables.
-- No automation: a full scan starts only from /pricelog scan; browse and commodity results are
-- recorded passively when you search the AH yourself. No network access, no file writing.
local ADDON, ns = ...
local C, Core = ns.Compat, ns.Core

local SCHEMA = 1
local SOURCE_FORMAT = 1
local SCAN_COOLDOWN = 15 * 60 -- ReplicateItems is limited to about once per 15 minutes
local DEFAULTS = { maxPoints = 200, keepDays = 90, dedupSeconds = 60, trendBand = 0.10 }

local db, settings, realm
local PL = {}
KennyPriceLog = PL

local migrations = {} -- schema 1 is the first release; future changes add [2] = function(db) ... end

local function realmData()
  local key = C.RealmFaction()
  local r = db.realms[key]
  if not r then r = { items = {}, latest = {}, lastScan = 0, scans = 0 }; db.realms[key] = r end
  return r
end

function PL.Median(list)
  local n = #list
  if n == 0 then return nil end
  local s = {}
  for i = 1, n do s[i] = list[i] end
  table.sort(s)
  if n % 2 == 1 then return s[(n + 1) / 2] end
  return (s[n / 2] + s[n / 2 + 1]) / 2
end

-- point = { t, min (lowest unit buyout, copper), median (unit), qty, src }
function PL.Record(itemID, name, minP, medianP, qty, src, now)
  if type(itemID) ~= "number" or type(minP) ~= "number" or minP <= 0 then return end
  now = now or C.Now()
  local it = realm.items[itemID]
  if not it then it = { pts = {} }; realm.items[itemID] = it end
  if name and name ~= "" then it.name = name end
  local last = it.pts[#it.pts]
  if src ~= "scan" and last and now - last.t < settings.dedupSeconds then
    if minP < last.min then last.min = minP end
    if (qty or 0) > (last.qty or 0) then last.qty = qty end
  else
    it.pts[#it.pts + 1] = { t = now, min = minP, median = medianP or minP, qty = qty or 0, src = src }
  end
  local cutoff = now - settings.keepDays * 86400
  while #it.pts > settings.maxPoints or (#it.pts > 1 and it.pts[1].t < cutoff) do table.remove(it.pts, 1) end
  local l = it.pts[#it.pts]
  realm.latest[itemID] = { p = l.min, t = l.t, n = l.qty }
end

-- Price-source plugins: getPrice(itemID) -> copper|nil, optional onScan(summary).
local sources = Core.NewRegistry("source", SOURCE_FORMAT, { "getPrice" })
function PL.RegisterSource(spec) return sources.Register(spec) end

-- Latest own-scan price, falling back to registered sources. Used by MatTooltip and FarmTracker.
function PL.GetLatest(itemID)
  if not realm then return nil end
  local l = realm.latest[itemID]
  if l then return l end
  for _, p in ipairs(sources.list) do
    local price = C.SafeNumber(sources.Call(p, "getPrice", itemID))
    if price and price > 0 then return { p = price, t = 0, n = 0, source = p.spec.id } end
  end
  return nil
end

-- Latest price vs the median of the previous 7 days of points.
function PL.Trend(itemID, now)
  local it = realm and realm.items[itemID]
  if not it or #it.pts < 3 then return "NOT ENOUGH DATA" end
  now = now or C.Now()
  local latest, prev = it.pts[#it.pts], {}
  for i = 1, #it.pts - 1 do
    if now - it.pts[i].t <= 7 * 86400 then prev[#prev + 1] = it.pts[i].min end
  end
  if #prev < 2 then return "NOT ENOUGH DATA" end
  local med = PL.Median(prev)
  local change = (latest.min - med) / med
  local band = settings.trendBand
  return (change > band and "RISING") or (change < -band and "FALLING") or "STABLE", med, change
end

local function csvField(s)
  s = tostring(s or "")
  if s:find('[,"\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end

function PL.BuildCSV(days, onlyItem, now, maxRows)
  now, maxRows = now or C.Now(), maxRows or 20000
  local cutoff = days and (now - days * 86400) or 0
  local rows, ids = { "itemID,name,date,min_buyout_copper,median_copper,quantity,source" }, {}
  for id in pairs(realm.items) do if not onlyItem or id == onlyItem then ids[#ids + 1] = id end end
  table.sort(ids)
  local truncated = false
  for _, id in ipairs(ids) do
    local it = realm.items[id]
    for _, o in ipairs(it.pts) do
      if o.t >= cutoff then
        if #rows > maxRows then truncated = true break end
        rows[#rows + 1] = table.concat({ id, csvField(it.name), date("!%Y-%m-%dT%H:%M:%SZ", o.t),
          o.min, math.floor(o.median or o.min), o.qty or 0, o.src or "" }, ",")
      end
    end
    if truncated then break end
  end
  return table.concat(rows, "\n"), #rows - 1, truncated
end

-- Full scan: lowest + median unit buyout and total quantity per item; chunked; waits out combat.
local processing = false
function PL.ProcessReplicate()
  if processing then return end
  processing = true
  local n = C.AHNumReplicate()
  local acc, i, now = {}, 0, C.Now()
  local function finish()
    local k, summary = 0, {}
    for id, a in pairs(acc) do
      PL.Record(id, a.name, a.min, PL.Median(a.units), a.qty, "scan", now)
      summary[id] = a.min
      k = k + 1
    end
    realm.lastScan, realm.scans = now, (realm.scans or 0) + 1
    processing = false
    for _, p in ipairs(sources.list) do
      if type(p.spec.onScan) == "function" then sources.Call(p, "onScan", summary) end
    end
    Core.Print("logged " .. k .. " items from the full scan.")
  end
  local function step()
    if C.InCombat() then C_Timer.After(1, step) return end
    local stop = math.min(i + 500, n)
    while i < stop do
      local itemID, name, count, buyout = C.AHReplicateRow(i)
      if itemID then
        local unit = math.floor(buyout / count)
        local a = acc[itemID]
        if not a then a = { min = unit, qty = 0, units = {}, name = name }; acc[itemID] = a end
        if unit < a.min then a.min = unit end
        a.qty = a.qty + count
        a.units[#a.units + 1] = unit
      end
      i = i + 1
    end
    if i < n then C_Timer.After(0, function() Core.SafeCall("scan", step) end) else finish() end
  end
  local ok = Core.SafeCall("scan", step)
  if not ok then processing = false end
end

local function OnBrowse()
  for _, r in ipairs(C.AHBrowse()) do
    PL.Record(r.itemID, C.GetItemName(r.itemID), r.price, nil, r.quantity, "browse")
  end
end

local function OnCommodity(itemID)
  itemID = C.SafeNumber(itemID)
  if not itemID then return end
  local rows = C.AHCommodity(itemID)
  if #rows == 0 then return end
  local minP, qty, prices = nil, 0, {}
  for _, r in ipairs(rows) do
    if not minP or r.price < minP then minP = r.price end
    qty = qty + r.quantity
    prices[#prices + 1] = r.price
  end
  PL.Record(itemID, C.GetItemName(itemID), minP, PL.Median(prices), qty, "search")
end

local f = CreateFrame("Frame")
local ahOpen, scanToken = false, 0
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
f:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
f:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    db = Core.Migrate(KennyPriceLogDB, migrations, SCHEMA)
    db.realms = db.realms or {}
    KennyPriceLogDB = db
    settings = Core.Settings(db.settings, DEFAULTS)
    realm = realmData()
    return
  end
  if not db then return end
  if event == "PLAYER_LOGIN" then
    realm = realmData() -- realm/faction are reliable from here on
    for key, r in pairs(db.realms) do
      if r ~= realm and next(r.items) == nil then db.realms[key] = nil end
    end
  elseif event == "AUCTION_HOUSE_SHOW" then ahOpen = true; realm = realmData()
  elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
    -- Fires repeatedly while item info streams in: process once, 2s after the last update.
    -- Also captures a full scan started from MatTooltip, so one scan feeds every addon.
    scanToken = scanToken + 1
    local token = scanToken
    C_Timer.After(2, function() if token == scanToken then PL.ProcessReplicate() end end)
  elseif C.InCombat() then return
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then Core.SafeCall("browse", OnBrowse)
  elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then Core.SafeCall("commodity", OnCommodity, arg1)
  end
end)

local function parseArgs(rest)
  local days, item
  for tok in (rest or ""):gmatch("%S+") do
    local lid = tok:match("item:(%d+)")
    if lid then item = tonumber(lid)
    elseif tonumber(tok) then if days == nil then days = tonumber(tok) else item = tonumber(tok) end end
  end
  if days == 0 then days = nil end
  return days, item
end
PL.ParseExportArgs = parseArgs

SLASH_KENNYPRICELOG1 = "/pricelog"
SLASH_KENNYPRICELOG2 = "/kpl"
SlashCmdList.KENNYPRICELOG = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "scan" then
    if not ahOpen then Core.Print("open the auction house first.") return end
    if C.InCombat() then Core.Print("not in combat.") return end
    local wait = SCAN_COOLDOWN - (C.Now() - realm.lastScan)
    if wait > 0 then Core.Print(("full scan available in %d min. Your item searches are still logged."):format(math.ceil(wait / 60))) return end
    if not C.AHReady() then Core.Print("AH busy, try again shortly.") return end
    C.AHReplicate()
    Core.Print("full scan requested. Stay at the AH until it reports.")
  elseif cmd == "export" then
    local days, item = parseArgs(rest)
    local text, rows, truncated = PL.BuildCSV(days, item)
    Core.ShowText("Export", ("PriceLog CSV: %d rows%s. Ctrl+C to copy."):format(rows,
      truncated and " (truncated: narrow it with days or an itemID)" or ""), text)
  elseif cmd == "trend" then
    local _, id = parseArgs("0 " .. rest)
    if not id then Core.Print("usage: /pricelog trend <itemID or link>") return end
    local label, med, change = PL.Trend(id)
    local l = realm.latest[id]
    Core.Print(("%d: %s%s"):format(id, label, med and (" (latest %s vs 7-day median %s, %+.0f%%)"):format(
      C.Money(l.p), C.Money(med), change * 100) or ""))
  elseif cmd == "stats" then
    local n, o = 0, 0
    for _, it in pairs(realm.items) do n = n + 1; o = o + #it.pts end
    Core.Print(("%s: %d items, %d points, %d full scans, last %s."):format(C.RealmFaction(), n, o, realm.scans or 0,
      realm.lastScan > 0 and date("%Y-%m-%d %H:%M", realm.lastScan) or "never"))
  elseif cmd == "plugins" then for _, l in ipairs(sources.Describe()) do Core.Print(l) end
  elseif cmd == "report" then
    local n = 0
    for _ in pairs(realm.items) do n = n + 1 end
    Core.ShowReport({ "schema " .. tostring(db.schema), "realm " .. C.RealmFaction(), "items " .. n,
      "full scans " .. tostring(realm.scans), "last scan " .. (realm.lastScan > 0 and date("%Y-%m-%d %H:%M", realm.lastScan) or "never"),
      "sources " .. #sources.list })
  elseif cmd == "wipe" and rest == "confirm" then
    db.realms[C.RealmFaction()] = nil; realm = realmData(); Core.Print("log wiped for " .. C.RealmFaction() .. ".")
  else
    Core.Print("/pricelog scan | export [days] [itemID] | trend <itemID> | stats | plugins | report | wipe confirm")
  end
end
