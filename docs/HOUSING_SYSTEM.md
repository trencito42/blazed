# SunsetMP housing system

Each exterior entrance represents one physical house. Interiors use a curated catalog and a routing bucket derived from the house ID, so occupants of different houses never share an interior even when the layout is the same. Apartment buildings can later add unit records without changing ownership or rental rules.

## Player flow

- Press `E` at an entrance to inspect, buy, rent, enter, set spawn, or lock a house when the action applies.
- A character may own one house and hold one active rental. Buying a house ends the active rental.
- Owners and active renters can enter locked houses. Unlocked houses allow guests.
- Rent is charged every payday at the price recorded when the rental began. Failure to pay ends the rental and removes that house as home spawn.
- Owned and rented houses appear as a house card in the login spawn selector. Spawning always places the player safely outside the entrance.
- The GTA radar is hidden while inside because instanced interiors reuse world coordinates; this prevents the minimap from misleadingly jumping to another property.

## Creation and administration

Stand on foot at the exact front door and use:

`/acreatehouse [price] [interior] [minimum level] [name]`

Use `/houseinteriors` to list the catalog. Admins can later change safe fields with `/ahouseedit [id] [price|level|name|sale|enabled] [value]`.

Owner commands are documented in `/help`: `/houselock`, `/houserent`, `/housemaxrenters`, `/houseinterior`, `/houserenters`, `/housekickrenter`, and `/sellhouse`.

All purchases, rental capacity checks, access, spawn choices, proximity, and admin permissions are validated by the server. Client-supplied coordinates and prices are never trusted.
