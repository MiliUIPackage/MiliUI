[![Donate to the author of Garrison Mission Manager](https://www.paypal.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cn=Add+special+instructions+to+the+addon+author%28s%29&business=rowaasr13%40gmail.com&bn=PP-DonationsBF%3Abtn_donateCC_LG.gif%3ANonHosted&lc=US&cmd=_donations&rm=1&no_shipping=1&currency_code=USD&return=https%3A%2F%2Fwww.curse.com%2Faddons%2Fwow%2Fgarrison-mission-manager&cancel_return=https%3A%2F%2Fwww.curse.com%2Faddons%2Fwow%2Fgarrison-mission-manager&item_name=Garrison+Mission+Manager+%28from+Curse.com%29) [![Support author of Garrison Mission Manager on Patreon](https://media-elerium.cursecdn.com/attachments/192/602/support-on-patreon26.png)](https://www.patreon.com/rowaasr13)

Garrison Mission Manager, v58

* http://www.curse.com/addons/wow/garrison-mission-manager
* http://www.wowinterface.com/downloads/info23375-GarrisonMissionManager.html

A tool to assists you with selecting best team for Battle for Azeroth mission table, Legion's Class Hall and WoD's Garrison/Shipyard missions and other followers management tasks.

# Additional downloads
* [LibTTScan](https://mods.curse.com/addons/wow/libttscan-1) - to show Artifact Power amount on mission rewards.
* [GMM - Load On Login](https://mods.curse.com/addons/wow/gmm-on-login) - to make GMM load on login and make all its features available right from entering the game instead of delaying load until you interact with Blizzard UI.

# Best team selection
The core of GMM is team selection: mission list will have one button and individual mission page will have top 3 buttons at Battle for Azeroth mission table, Class Hall, Shipyard and Garrison. Clicking any of those button set suggested team. Each button will show you success rate along with icons of bonuses gained by that team or reduced time. Hovering over those buttons will show tooltip with suggested team.

GMM checks all combinations of all followers and selects those that give best total success chance reported directly from WoW. This takes care of each and every trait and ability your followers have, present and future, without any need for special updates.

# Shared features

## WoD garrison/shipyard landing page
After GMM is loaded (i.e. you've opened any garrison interface or landing page at least once), right clicking the minimap button will show WoD garrison/shipyard landing page even if you already have Class Hall. (Just like all other feature this requires GMM to be loaded -  i.e. you need any garrison interface or landing page at least once or install [GMM - Load On Login](https://mods.curse.com/addons/wow/gmm-on-login)).

## Additional team selection features

### Yield mode
A second set of 3 more buttons will appear on missions offering material (GR/Apexis/Oil) or gold rewards, showing best choices for maximizing those resources, sacrificing other optimizations like using lowest possible followers. Those teams are also optimized for long term gain - i.e. you could have lower success rate on individual missions, but your material/gold yield will be better on average over time.

### Fully maxed followers
GMM will not suggest fully maxed teams on missions that only grant XP as long as you have unmaxed followers. If you don't have salvage yard and only have fully maxed followers GMM will not suggest teams for XP missions at all - this will be indicated by empty suggestion buttons on such missions. However when all your unmaxed are busy and if you do have salvage yard, GMM will send remaining maxed followers on those missions as well to allow you to hunt for salvage crates. This mode is indicated by salvage bag/crate icon appropriate for mission.

### Inactive/busy followers
GMM will also check busy followers - those working, on mission, deactivated or otherwise unavailable right now. A set of 3 more "disabled" buttons in lower right corner will show best teams considering every available follower. Tooltip for those buttons will show currently unavailable followers in red and will show their status and remaining time if they're on mission.

## Mission list improvements

### Best teams at a glance
GMM adds a top team button to each mission on mission list page in both main garrison building and naval mission table in your shipyard so you can see at a glance which missions you could reliably do with your current followers. Clicking this button will take you to mission page and automatically sets suggested team.

### Expiration time
Mission expiration time will be shown in lower left corner of each mission's button. Since XP-only missions don't present any unique rewards, they won't be tracked to reduce clutter in UI, except for rare missions that offer huge rewards with low level requirements. Time on missions with less than 8 hours remaining will be shown in red.

### More prominent item level
You don't really want to know that all your item level missions are level 100. Item level on such missions will no longer be tucked in parenthesis below big 100, but will instead just replace level 100 indicator completely. Item levels will also have a slightly brighter color to make those missions stand out, as they usually offer better rewards.

### Impossible missions
Missions that require more followers or garrison resources than you currently have will be dimmed out to let you concentrate on missions that you can do.

# Garrison-specific features

## Worker follower warnings
Followers with appropriate profession traits can boost working orders in production buildings. Since patch 6.1, follower must be in the building at the moment when each individual order completes to boost output. When you add a follower to the party on a mission screen a warning will appear bellow follower's portrait if you have appropriate building where he can work so you won't accidentally send on follower on a long mission that you wanted to put in a building. If there's no orders in progress, warning will be shown in yellow with just a name of building. If there are orders in progress, warning will be in red and will show time until next completed order and number of remaining orders in addition to building's name.

## Mass set/remove followers to work in buildings
GMM adds buttons at garrison architect table that will allow you to automatically mass-assign all available workers to buildings or mass-remove them. Note that Blizzard throttles follower assignment/removal, so it could take a second or two to finish. Be sure to wait for buttons to switch states and usual follower assign/remove click sound before leaving architect table. GMM will always prefer the best follower for building - that is, with highest level available, because that influences actual yield and will not select lower level followers when higher level follower is busy. If you have several same level followers,  GMM will select free follower with lowest ilevel. Tooltips on the buttons will show which follower will be added/removed from each building. If best intended follower is not available - e.g. on the mission, it will be show in orange on assign button tooltip. Buildings that have a slot but don't have suitable followers at all will be shown in red.

## LDB module
If you have any display addon that supports LDB modules - e.g. Titan Panel or FuBar - GMM adds a module that for now will show list of buildings with followers both as icons on panel and tooltip similar to that on mass "Remove" button to help you quickly asses if your follower is working in those buildings that don't have readily visible indication like Lumber Mill, Garden or Mine or to remind you that some of your followers are assigned when you're hanging at mission table. The tooltip will also include list of buildings that you have no followers for in red. Note that GMM only loads on-demand with Blizzard's garrison UI, so you won't see display or even module itself listed in available modules list until you load garrison UI by interacting with any garrison facility - e.g. mission or architect table. You can also simply click "garrison report" on your minimap to load it.

# Shipyard-specific features

## Fleet summary
[(screenshot)](https://media-elerium.cursecdn.com/attachments/96/210/GMM_FleetSummary.png)

When you access ship builder, you'll see a number of each type of ships you have in chat window, so you can quickly decide what to build.

GMM aims to be fast and lightweight, keeping CPU and memory use to the minimum, requiring no configuration and generally just doing the right thing with a single click.