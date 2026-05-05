# Lead Sight Revamped

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Lead Sight Revamped** is the officially maintained continuation of the original Lead Sight mod, updated for modern Avorion versions with stability, multiplayer, and quality-of-life improvements.

## 📜 Background & Credits

* **Original Mod Author & Core Concept:** [SigmatroN](https://steamcommunity.com/profiles/76561198196116626)
* **Original Workshop Link:** [Lead Sight](https://steamcommunity.com/sharedfiles/filedetails/?id=2538356784)
* **Current Maintenance & Development:** Stormbox

After a multi-year hiatus, I have officially taken over development of this mod to ensure it remains functional for the Avorion community. This project preserves the original behavior and credits while modernizing compatibility. Special thanks to SigmatroN for providing the critical audio/crash hotfix that made this revamp possible.

## 🎯 What the Mod Does

The mod provides predictive lead gun sights for projectile weapons, helping you land shots on moving targets more reliably.

* Calculates reticle lead based on target and shooter relative velocity.
* Supports a quick toggle on/off (Default Key: `/`).
* Uses range-based reticle color feedback:
  * 🔴 **Red:** Out of reach
  * 🟡 **Orange/Yellow:** Partial reach (some weapons can connect)
  * 🟢 **Green:** Favorable reach window

## 🛠️ Current Improvements in Revamped Version

* Added defensive runtime guards for player/entity/velocity access.
* Preserved and retained the no-buzz/no-crash laser sound fix provided by the original author (`newEffect.soundMaxRadius = 0` and `newEffect.soundVolume = 0`).
* Added configurable behavior flags in the script:
  * `toggleKey`
  * `chatFeedbackEnabled`
  * `soundFeedbackEnabled`
  * `debugEnabled`
* Added safer effect usage handling for transient/invalid laser references.

## ⚠️ Known Gameplay/Engine Limitations

* The reticle is rendered as a world-space 3D visual, meaning depth/occlusion can occasionally hide it behind objects.
* Weapon averaging still reflects turret data constraints from game API behavior (all projectile weapons, even in inactive groups, are taken into account).
* Final multiplayer behavior should be validated on a dedicated server with multiple players in-sector.

## 📁 File Notes & License

* **Active scripts:** `data/scripts/player/init.lua`, `data/scripts/player/leadSight.lua`
* **Archive backups:** `data/scripts/player/init(OLD).lua`, `data/scripts/player/leadSight(OLD).lua`
* **License:** Portions derived from the base Avorion game are property of the Avorion creators. Original mod copyright 2021 by SigmatroN. Revamped additions copyright 2026 by Stormbox. Released under the MIT License.
