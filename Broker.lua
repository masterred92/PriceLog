-- LibDataBroker display for Titan Panel, ChocolateBar, Bazooka and other LDB displays (only if one is installed).
local _, ns = ...
local PL = KennyPriceLog
local C = ns.Compat
local obj

local function ago(t)
  if not t or t <= 0 then return "never" end
  local sec = C.Now() - t
  if sec < 3600 then return math.max(1, math.floor(sec / 60)) .. "m ago" end
  if sec < 86400 then return math.floor(sec / 3600) .. "h ago" end
  return math.floor(sec / 86400) .. "d ago"
end

function PL.UpdateBroker()
  if not obj then return end
  local n, _, last = PL.Stats()
  obj.text = ("%d prices, scan %s"):format(n, ago(last))
end

function PL.InstallBroker()
  if obj then return obj end
  -- One shared "Kenny's addons" entry with a menu when several of our addons are installed; our own entry when alone.
  obj = ns.Hub.Launcher("PriceLog", {
    leftHint = "Open",
    type = "data source", text = "Price Log", label = "Price Log",
    icon = "Interface\\AddOns\\PriceLog\\media\\icon",
    OnClick = function(_, button)
      SlashCmdList.KENNYPRICELOG(button == "RightButton" and "export" or "stats")
    end,
    OnTooltipShow = function(tt)
      local n, scans, last = PL.Stats()
      tt:AddLine("Price Log")
      tt:AddDoubleLine("Items logged", n, 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Full scans", scans, 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Last full scan", ago(last), 1, 1, 1, 1, 1, 1)
      tt:AddLine("Left-click: stats in chat. Right-click: CSV export.", 0.6, 0.6, 0.6, true)
    end,
  })
  PL.UpdateBroker()
  return obj
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then PL.InstallBroker() else PL.UpdateBroker() end
end)
