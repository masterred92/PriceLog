package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
local ns = W.loadAddon(".", "PriceLog")
W.fire("PLAYER_LOGIN"); W.runTimers()
local PL, db = KennyPriceLog, KennyPriceLogDB
check(db.schema == 1 and db.realms["TestRealm-Alliance"], "schema 1, realm-faction key")
local realm = db.realms["TestRealm-Alliance"]

SlashCmdList.KENNYPRICELOG("scan")
check(not W.replicateRequested, "refused with AH closed")
W.fire("AUCTION_HOUSE_SHOW")
SlashCmdList.KENNYPRICELOG("scan")
check(W.replicateRequested == 1, "scan requested")
W.replicate = { { 2318, 20, 400 }, { 2318, 5, 100 }, { 2318, 10, 300 }, { 2447, 10, 200 } }
W.fire("REPLICATE_ITEM_LIST_UPDATE"); W.runTimers()
local p = realm.items[2318].pts[1]
check(p.min == 20 and p.qty == 35 and p.median == 20 and p.src == "scan", "scan min/median/qty")
check(realm.latest[2318].p == 20, "latest updated")
check(realm.items[2318].name == "Light Leather", "name stored")
SlashCmdList.KENNYPRICELOG("scan")
check(W.replicateRequested == 1, "15-minute cooldown respected")

-- browse + commodity searches recorded passively, deduped within 60s
W.now = W.now + 3600
W.browse = { { itemKey = { itemID = 2447 }, minPrice = 25, totalQuantity = 40 } }
W.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
W.commodity[2447] = { { unitPrice = 22, quantity = 5 }, { unitPrice = 30, quantity = 10 }, { unitPrice = 40, quantity = 1 } }
W.now = W.now + 10
W.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2447)
local pts = realm.items[2447].pts
check(#pts == 2 and pts[2].min == 22 and pts[2].src == "browse", "dedup merged search into browse point")
W.combat = true; W.now = W.now + 120
W.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(#realm.items[2447].pts == 2, "nothing recorded in combat")
W.combat = false
W.secret[25] = true; W.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"); W.secret[25] = nil
check(#realm.items[2447].pts == 2, "secret price ignored")

-- trend vs 7-day median
for i, price in ipairs({ 100, 100, 100, 130 }) do PL.Record(249399, "Frilled Lichen", price, nil, 1, "scan", W.now + i * 3600) end
check(PL.Trend(249399, W.now + 5 * 3600) == "RISING", "rising")
PL.Record(249399, nil, 80, nil, 1, "scan", W.now + 6 * 3600)
check(PL.Trend(249399, W.now + 6 * 3600) == "FALLING", "falling")
PL.Record(249399, nil, 101, nil, 1, "scan", W.now + 7 * 3600)
check(PL.Trend(249399, W.now + 7 * 3600) == "STABLE", "stable")
check(PL.Trend(249427) == "NOT ENOUGH DATA", "no data")
check(PL.Median({ 3, 1, 2, 10 }) == 2.5, "median even")

-- CSV
PL.Record(1, 'Odd, "Name"', 5, nil, 1, "scan", W.now)
local csv, rows = PL.BuildCSV(nil, nil, W.now + 10 * 3600)
check(csv:match("^itemID,name,date,min_buyout_copper,median_copper,quantity,source\n"), "csv header")
check(csv:find('1,"Odd, ""Name""",', 1, true), "csv quoting")
check(csv:find("2318,Light Leather,%d%d%d%d%-%d%d%-%d%dT") ~= nil, "iso date")
check(rows == #csv:gsub("[^\n]", "") , "row count")
local only = select(2, PL.BuildCSV(nil, 2447, W.now + 10 * 3600))
check(only == 2, "item filter")
local d, it = PL.ParseExportArgs("7 |cff|Hitem:2447::|h[Peacebloom]|h|r")
check(d == 7 and it == 2447, "export args with link")
SlashCmdList.KENNYPRICELOG("export 0")
check(_G["KennyPriceLogExportWindow"] and _G["KennyPriceLogExportWindow"].shown, "export window")

-- price-source plugins
check(PL.GetLatest(249427) == nil, "no price without scan")
local scanned
check(PL.RegisterSource({ id = "src", format = 1, getPrice = function(id) return id == 249427 and 777 or nil end,
  onScan = function(sum) scanned = sum end }), "source registered")
PL.RegisterSource({ id = "broken", format = 1, priority = 1, getPrice = function() error("bad source") end })
check(PL.GetLatest(249427).p == 777, "source fallback, broken source contained")
check(PL.GetLatest(2318).p == 20, "own scan wins over sources")
W.now = W.now + 3600; SlashCmdList.KENNYPRICELOG("scan"); W.fire("REPLICATE_ITEM_LIST_UPDATE"); W.runTimers()
check(scanned and scanned[2318] == 20, "onScan notified")

-- report <= 2000 chars, with errors
for i = 1, 12 do ns.Core.RecordError("t" .. i, string.rep("x", 300)) end
check(#ns.Core.errors == 5, "ring buffer capped at 5")
local rep = ns.Core.BuildReport({ "state" })
check(#rep <= 2000 and rep:find("1.60.1 (70374)", 1, true), "report capped and has build")

-- settings proxy
local store = {}
local s = ns.Core.Settings(store, { a = 1 })
s.a = 2; check(store.a == 2, "non-default stored"); s.a = 1; check(store.a == nil and s.a == 1, "default stores nil")
-- schema newer than supported is left alone and reported
local _, ok = ns.Core.Migrate({ schema = 9 }, {}, 1)
check(ok == false, "future schema not migrated")
-- 0.3.0: Auctionator fallback, size readout, shared price service
Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(caller, id) if caller == "PriceLog" and id == 424242 then return 777 end end } } }
local rec = KennyPriceLog.GetLatest(424242)
check(rec and rec.p == 777 and rec.source == "Auctionator", "Auctionator used as a fallback")
Auctionator = nil
check(KennyPriceLog.GetLatest(424242) == nil, "no Auctionator: no price, no error")
local items, points, kb = KennyPriceLog.Size()
check(items > 0 and points >= items and kb >= 0, "size readout")
check(KennyAddonsHub.prices.PriceLog ~= nil, "registered as the shared price store")
W.done("PriceLog")
