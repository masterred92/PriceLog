# Changelog

## 0.2.0
- LibDataBroker display (Titan Panel, ChocolateBar, Bazooka...): prices logged and time since the last full scan; left-click stats, right-click CSV export.
- Tests now fail CI on any luacheck warning, and the API check also covers LibDataBroker calls.

## 0.1.0 (first public release)
- Added the CurseForge and Wago project IDs to the TOC for automatic packaging, and an icon for the AddOns list (`media/icon.tga`).
- Logs AH prices from your own full scans and searches, stored separately for each realm and faction.
- `/pricelog trend`, `/pricelog export` (CSV), a plugin API, and a bug-report window.
- Known limitation: a scan at a **neutral** AH is stored under your faction. Use NeutralFlip for neutral prices; a fix is planned.
- Game version: WoW: Forever 1.60.1 (Interface 16001).
