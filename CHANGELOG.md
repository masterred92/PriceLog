# Changelog

## 0.3.0
- Now the price source for NeutralFlip, MatTooltip and GoldPerSpot: one scan, one price store.
- Uses Auctionator's prices when it has none of its own.
- `/pricelog stats` shows how much the log uses, and the log keeps a fixed size.
- A short guide on first login; one shared display-bar entry.
- `/pricelog debug` checks your setup: client version, every game API the addon needs, and which of Kenny's other addons it is working with.
- A loud chat warning if this client is missing an API the addon needs, instead of failing silently.
- English text now lives in `Locales/enUS.lua`, ready for translations.
- Shared code (KennyShared) is identical in every addon of the family and checked in CI, along with every Blizzard API call (against the Forever UI source) and every DBM/BigWigs/Questie API call (against their source).

## 0.2.0
- LibDataBroker display (Titan Panel, ChocolateBar, Bazooka...): prices logged and time since the last full scan; left-click stats, right-click CSV export.
- Tests now fail CI on any luacheck warning, and the API check also covers LibDataBroker calls.

## 0.1.0 (first public release)
- Added the CurseForge and Wago project IDs to the TOC for automatic packaging, and an icon for the AddOns list (`media/icon.tga`).
- Logs AH prices from your own full scans and searches, stored separately for each realm and faction.
- `/pricelog trend`, `/pricelog export` (CSV), a plugin API, and a bug-report window.
- Known limitation: a scan at a **neutral** AH is stored under your faction. Use NeutralFlip for neutral prices; a fix is planned.
- Game version: WoW: Forever 1.60.1 (Interface 16001).
