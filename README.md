# Sim Sim Mission Win
## Introduction
This an attempt to create a new replacement for the World of Warcraft addon [Venture Plan](https://www.townlong-yak.com/addons/venture-plan), without reuse and distribution of its ARR code.

While the addon has proved invaluable and helpful to so many, the author's licensing choice, and subsequent hiatus has left many in a difficult situation. The rights to continue it with a new author are available under specific terms, so we may see a new version in time, but this doesn't solve the immediate need, and I wish to avoid a repeat of the situation, while creating a addon that does some things differently to Venture Plan and can be continued without me.

## Development
Development will be broken down into the following stages (some concurrent and part of an ongoing iterative cycle):
- [x] Automate creation of simulation spell data from the WoW files, with output compatible with Venture Plan
- [ ] Full verification of data against a modified version of Venture Plan (until its simulations can be fully replaced)
- [ ] Additional modification of Venture Plan for required simulation logic changes and verification (until its simulations can be fully replaced)
- [ ] Creation of the new addon that implements the required sim data and logic for use alongside Venture Plan (until feature parity is achieved)
- [ ] Achieve feature parity with Venture Plan, thus eliminating it from the development process
- [ ] Release addon
- [ ] Make further improvements to the data automation process
- [ ] Enhance the addon with new and improved features

**Please note:** No code for Sim Sim Mission Win itself will appear in this repository until the first version of the addon is ready to be tested, so until then, only [documentation](https://github.com/zealvurte/SimSimMissionWin/issues?q=label:documentation) will exist. Additionally, **no code from Venture Plan will appear in this repository**, except for necessary reference point snippets in issues during development, so **don't expect this work to help you get a version of Venture Plan that simulates correctly** without a lot of discovery and editing yourself.

## Simulation data
The data initially exists in the Google Sheet [SimData: Spells](https://docs.google.com/spreadsheets/d/1sDbpMaQUaHaJ-daScq4Qi1AQDoFnnYw_pU5G6qrkBKU), which also serves as the primary location for marking verification status and comments for each effect. From here, it is processed through [SimData-Spells_tsv-to-lua.lua](SimData-Spells_tsv-to-lua.lua), with each output handled as follows:
- First table: Saved to [SimSimMissionWin/SimData.lua](SimData.lua) (for future addon use)
- Second table: Saved to VenturePlan/vs-spells.lua (for verification), and as `vpData` in [SimData-Spells_tsv-to-lua.lua](SimData-Spells_tsv-to-lua.lua) (for future comparison)
- Comparison lines: Checked for unexpected results when compared with previous versions

**Please note:** The first table is only compatible with my own modified version of Venture Plan by default, as several of the optimisations and values Venture Plan uses have been forgone in favour of improved accuracy and debugging requirements. Instead you can produce a table for Venture Plan by using your own values from VenturePlan/vs-spells.lua for `vpData` in [SimData-Spells_tsv-to-lua.lua](SimData-Spells_tsv-to-lua.lua), commenting out the second to last line, and uncommenting the last line. This will then output an appropriate table, followed by the comparison lines against your old values.

### Spell effect verification

| Build | Accuracy | Correct | Incorrect | Unverified | N/A | Total |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: |
| 9.1.5.40622 | 88.53% ± 11.47% | 309 | 0 | 92 | 45 | 446 |

## Contributing
The best way you can contribute is through issues if you spot any mistakes or have suggestions for improvements. Where applicable, it would be helpful for you to provide logs of missions with issues, especially if you have any that are for unverified spells.

I won't be accepting pull requests for this project at this point in time, but may do so in the future.

## Ownership and licence
I explicitly don't plan to retain ownership of this addon once completed, as I'm unlikely to be able to maintain it myself and will eventually be taking my own hiatus from WoW. I would like to hand it over to someone else or a community team, so when that time comes, I will be looking for suitable volunteers to take it over; however, as this is released under GPLv3, there's nothing stopping someone else forking it themselves anyway, but be aware that the rights to the addon name are retained by me or whoever I later grant them to.

Data required for simulation is taken from World of Warcraft via [WoW.tools](https://wow.tools/), and is therefore owned by and copyright Blizzard Entertainment, Inc.
