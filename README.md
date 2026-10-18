# Price Log (WoW: Forever) v0.1.0

> [!WARNING]
> **Untested in-game. Use at your own risk.** WoW: Forever has not launched yet (Nov 4 2026), so none of this has run in the real client.
> - API usage is verified against Blizzard's UI source only (Gethe/wow-ui-source `forever` branch, 1.60.1 build 70374), plus luacheck and mock-client tests.
> - Item IDs were checked against auctionhouse.fyi's Forever item data (build 1.60.1.70009), not in-game.
> - `## Interface: 16001` is unconfirmed (the UI source .toc files show `0`).
> - Found a bug? Use the addon's `report` command and [open an issue](https://github.com/masterred92/wow-forever-addons/issues).

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

## Commands
`/pricelog scan` · `export [days] [item]` · `trend <item>` · `stats` · `plugins` · `report` · `wipe confirm` (this realm/faction only) · alias `/kpl`

## Install
1. Download the addon zip from [Releases](https://github.com/masterred92/wow-forever-addons/releases) (or copy the folder from this repo).
2. Put the addon folder (e.g. `FarmTracker`) in `World of Warcraft\_forever_\Interface\AddOns\`. That folder sits next to `_retail_`; the exact name may differ.
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
