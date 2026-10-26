<p align="center"><img src="media/logo.png" alt="PriceLog logo" width="200"></p>

# Price Log (WoW: Forever) v0.2.0

[![Tests](https://github.com/masterred92/PriceLog/actions/workflows/tests.yml/badge.svg)](https://github.com/masterred92/PriceLog/actions/workflows/tests.yml) [![WoW: Forever](https://img.shields.io/badge/WoW%3A%20Forever-Interface%2016001-c8a165)](https://github.com/masterred92/PriceLog/blob/main/PriceLog.toc) [![Release](https://img.shields.io/github/v/release/masterred92/PriceLog?label=release)](https://github.com/masterred92/PriceLog/releases) [![License: MIT](https://img.shields.io/github/license/masterred92/PriceLog)](https://github.com/masterred92/PriceLog/blob/main/LICENSE) [![CurseForge](https://img.shields.io/badge/CurseForge-PriceLog-f16436)](https://www.curseforge.com/wow/addons/pricelog) [![Wago](https://img.shields.io/badge/Wago-PriceLog-c1272d)](https://addons.wago.io/addons/pricelog)

Records auction house prices **from your own scans and searches** into SavedVariables, kept separately for each realm and faction:
- **Full scan:** `/pricelog scan` at an open AH. This is Blizzard's full-AH replicate, limited to about once per 15 minutes; the addon tells you how long is left. For every item it stores the lowest unit buyout, the median unit buyout and the total quantity.
- **Your searches:** when you browse or search the AH yourself, the shown lowest price and quantity are recorded too, at most one point per item per minute.
- A full scan started from MatTooltip is captured as well, so one scan feeds every addon.
- Up to 200 points per item, kept for 90 days.

**Trend:** `/pricelog trend <item>` compares the latest price to the median of the previous 7 days. It shows **RISING** (more than 10% above), **FALLING** (more than 10% below) or **STABLE**, and NOT ENOUGH DATA with fewer than 3 points.

## Export
WoW addons can't write files, so there are two ways to get the data out:
1. `/pricelog export [days] [itemID or link]` opens a window with CSV text already selected: press Ctrl+C and paste into a spreadsheet. The columns are `itemID,name,date,min_buyout_copper,median_copper,quantity,source`, with UTC ISO dates. Large logs are capped at 20,000 rows, so narrow by days or item if it says "truncated".
2. **Offline path:** after you log out or `/reload`, everything is in `World of Warcraft\_forever_\WTF\Account\<ACCOUNT>\SavedVariables\PriceLog.lua` (the `KennyPriceLogDB` table), which a Python script can read next to auctionhouse.fyi data.

**New in 0.2.0**
- **LDB display:** with Titan Panel, ChocolateBar, Bazooka or another LibDataBroker display, Price Log shows how many prices are logged and when your last full scan was. Left-click prints stats, right-click opens the CSV export.

## Download
- **CurseForge:** https://www.curseforge.com/wow/addons/pricelog (first release coming at launch, Nov 4). Author: [MasterRed92](https://www.curseforge.com/members/masterred92/projects).
- **Wago Addons:** https://addons.wago.io/addons/pricelog (first release coming at launch, Nov 4).
- **GitHub:** [Releases](https://github.com/masterred92/PriceLog/releases) (coming with the first tagged release) · [Issues](https://github.com/masterred92/PriceLog/issues)
- **Companion addons** (optional, they share AH scans): [NeutralFlip](https://github.com/masterred92/NeutralFlip) · [MatTooltip](https://github.com/masterred92/MatTooltip) · [GoldPerSpot](https://github.com/masterred92/GoldPerSpot)

## Commands
`/pricelog scan` · `export [days] [item]` · `trend <item>` · `stats` · `plugins` · `report` · `wipe confirm` (this realm/faction only) · alias `/kpl`

## Install
1. Download the addon zip (see Download above) or clone this repo into a folder named `PriceLog`.
2. Put the addon folder (`PriceLog`) in `World of Warcraft\_forever_\Interface\AddOns\`. That folder sits next to `_retail_`; the exact name may differ.
3. Restart the game, or type `/reload`. Check it is ticked in the AddOns list on the character screen.

## In-game test checklist
1. PriceLog loads; `/pricelog stats` shows your realm-faction and "never".
2. At a faction AH, `/pricelog scan`: within a minute or two, "logged N items". A second `scan` right away says how many minutes until the next one.
3. Search Light Leather in the AH yourself, then run `/pricelog trend Light Leather` (shift-click the link): it reports a point count or trend, with no errors.
4. `/pricelog export`: the window opens with the text selected; Ctrl+C, paste into a spreadsheet, and the columns line up.
5. `/reload`, then open `WTF\...\SavedVariables\PriceLog.lua`: the data is there.
6. Scan with MatTooltip's `/mattip scan` instead: PriceLog also logs it.
7. No lag spike or "script ran too long" error during the scan, even on a full AH. If there is one, report it with `/pricelog report`.
8. On a second character of the other faction, the data is kept separate.
9. In the AddOns list (character select or Esc > AddOns), PriceLog shows its icon. If it shows a blank or green square, report it; the addon still works.
10. With Titan Panel or ChocolateBar: the Price Log display shows '<n> prices, scan <time>'; left-click prints stats, right-click opens the export.

## Development
`tests/run.sh [path-to-wow-ui-source-forever]` runs `luac -p`, luacheck, the mock-client tests and (with a path) the API check against Blizzard's UI source. GitHub Actions runs the same on every push. Releases are packaged by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) only when a `v*` tag is pushed.
