# FishStat
Addon for World of Warcraft retail version. Collects catch statistics for the Fishing profession.

[Russian read me](https://github.com/Mu57Di3/FishStat/blob/main/README_RU.md)

## Features

- A new session statistics is created upon using the /reload command or on logout/login, while overall statistics are also saved.
- Integration with the Auctionator addon to fetch auction prices and display them on the session page, so you can see an approximate amount you can earn.
- Automatically hides during combat and collapses into an icon near the map. Uses the system Fishing icon.
- In each zone, shows the fishing skill level for the expansion that zone belongs to. For correct operation, open the Fishing Journal when you log in.
- A window showing “fish” in your inventory and its value. Data is taken from the addon’s catch database.
- Displays the amount of accumulated poison on The Coiled Huntress fishing rod.
- Console commands: `/fishstat`, `/fishstat reset`, `/fishstat minimap`

## Install

1. Copy the `FishStat` folder to:
   `World of Warcraft\_retail_\Interface\AddOns\`
2. Enable **FishStat** in the AddOns menu.
3. `/reload`

