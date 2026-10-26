package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
local ldbObjs = {}
LibStub = setmetatable({}, { __call = function(_, name, silent) if name == "LibDataBroker-1.1" then return { NewDataObject = function(_, n, o) ldbObjs[n] = o; return o end } end assert(silent) end })
local tt = { lines = {} }
function tt:AddLine(s) self.lines[#self.lines + 1] = tostring(s) end
function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. ": " .. tostring(b) end
local function ttText(o) tt.lines = {}; o.OnTooltipShow(tt); return table.concat(tt.lines, " | ") end
W.loadAddon(".", "PriceLog")
W.fire("PLAYER_LOGIN")
local PL = KennyPriceLog
local o = ldbObjs.PriceLog
check(o and o.text == "0 prices, scan never", "LDB object, empty log")
PL.Record(2447, "Peacebloom", 100, 100, 5, "search")
PL.UpdateBroker()
local n, scans, last = PL.Stats()
check(n == 1 and scans == 0 and last == 0, "PL.Stats counts items")
check(o.text == "1 prices, scan never", "LDB text updates")
check(ttText(o):find("Items logged: 1"), "LDB tooltip")
o.OnClick(nil, "LeftButton")
check(W.prints[#W.prints]:find("1 items"), "LDB click shows stats")
W.done("PriceLog extras")
