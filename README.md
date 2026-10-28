# Help or Not

Mark players as Griefer, Rude, Annoying, KOS or Helpful. Block the bad ones' chat, whispers, trades, group/guild invites and duels, and stamp them DO NOT HELP (or KILL ON SIGHT, or HELPFUL) on nameplates, unit frames (EllesmereUI or Blizzard), tooltips and Group Finder.

Clients: Retail 12.1, WoW Forever 1.60.1, Classic Era, TBC Anniversary, MoP Classic.

## Install
Drop the `HelpOrNot` folder into each client's `Interface/AddOns`. Lists are saved per client, so use `/hon export` and `/hon import` to copy yours between them.

## Use
- Right-click any player (unit frame, chat name, friends, guild) > Help or Not > Mark player
- Or target them: `/hon add griefer [note]`
- `/hon` opens the list: change category, toggle blocks per player, remove
- Helpful players get a green HELPFUL stamp, no blocks, and a quiet chat line when they join your group
- KOS (kill on sight) is for your PvP nemesis list: a purple skull KILL ON SIGHT stamp, a raid warning when their nameplate shows up near you, and a last seen time and zone in their tooltip
- `/hon options` (or the Options button, or Esc > Options > AddOns > Help or Not) turns any feature on or off: stamps, alerts, KOS sightings, each kind of block, and the right-click menu
- `/hon test` marks yourself as a Griefer temporarily so you can see the stamps

## Limits
- Friendly nameplates in PvE instances are locked by Blizzard. Raid/party frames carry the marking there.
- In Midnight, chat authors are hidden from addons inside instances. Turn on Ignore for a hard block there.
- Visual only. Nothing can stop a click-heal on a flagged player.
