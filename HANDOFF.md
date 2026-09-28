# Help or Not: project handoff

WoW addon that lets the player mark other players as Griefer, Rude, Annoying or Helpful, blocks the bad ones, and shows DO NOT HELP (or HELPFUL) stamps on nameplates, unit frames, tooltips and Group Finder. Author credit: Monger. Repo: github.com/ceckles/Help-or-Not. CurseForge project "Help or Not" is created and awaiting moderator approval.

Excluded from the packaged zip via `.pkgmeta`.

## Owner preferences
Direct, casual, no fluff. No em dashes anywhere, including user-facing strings and docs. Research and verify before answering; never guess API behavior. Owner is an advanced engineer, no need to explain fundamentals.

## Clients and TOC
One TOC, comma-separated interfaces: 11508, 11509 (Classic Era), 16001 (WoW Forever 1.60.1, shares Mainline API), 20505, 20506 (TBC Anniversary), 50503, 50504 (MoP Classic), 120100, 120105 (Retail 12.1 / 12.1.5 PTR). Verify current numbers against warcraft.wiki.gg TOC_format before bumping. TOC also has: Author Monger, Category Chat (with localized Category-xxXX lines), AddonCompartmentFunc hooks, SavedVariables HelpOrNotDB, OptionalDeps EllesmereUI, X-License All Rights Reserved. Repo root is the addon folder. `.pkgmeta` sets package-as HelpOrNot because the repo name (Help-or-Not) differs from the TOC name.

## Files
- Core.lua: namespace (`_G.HelpOrNot`), categories and flags, name keys (`name-realm` lowercased, realm spaces/hyphens stripped), secret value guard `ns.IsSecret`, DB init, add/remove/setFlag, Blizzard ignore sync (tracks `ignoredByUs` so it never removes the user's own ignores), export/import (prefix HON1, still accepts DNH1), throttled notices, event dispatcher (`ns.On` pcalls RegisterEvent since unknown events error), `ns.OnLogin`, `ns.OnChange`/`ns.Fire`.
- Visuals.lua: unit frame stamp (tint + border + icon + text), nameplate stamp, center target banner. Griefers pulse. Helpful uses ReadyCheck-Ready icon and lighter tint.
- Filters.lua: chat mute and whisper filters, auto cancel trade (partner unit is "NPC"), decline group/guild invites and duels.
- Frames.lua: UI-agnostic scanner. EnumerateFrames out of combat, finds Buttons with a secure `unit` attribute (player, target, focus, partyN, raidN, arenaN), overlays a non-secure stamp. 1s ticker refresh. This is how EllesmereUI frames get marked without depending on EUI internals.
- Plates.lua: stamps on `C_NamePlate.GetNamePlateForUnit` plates. "Marked only" mode: sets `nameplateShowFriends` to 1 outside PvE instances, fades every unmarked friendly player plate's children to alpha 0 (hooks SetAlpha to keep them hidden), restores on NAME_PLATE_UNIT_REMOVED since plates recycle, sets friendly click-through. In party/raid/scenario instances it restores the user's saved CVar value. CVar changes deferred out of combat.
- Tooltip.lua: TooltipDataProcessor post-call, falls back to OnTooltipSetUnit.
- Alerts.lua: raid warning + sound when a marked bad player joins group, banner on target. Helpful players get a quiet chat line only, no banner.
- Menu.lua: Menu.ModifyMenu on unit/chat/friend/guild menu tags, add-with-note StaticPopup.
- LFG.lua: overlays tags on LFGListSearchEntry and applicant members (overlay only, never rewrites Blizzard text, to avoid taint).
- UI.lua: `/hon` manager window (rows with category cycle, per-flag checkboxes, note, delete), settings checkboxes, export/import popups, slash commands (/hon, /helpornot), addon compartment functions.

## Verified platform constraints
- ChatFrame_AddMessageEventFilter global removed in 12.0, use ChatFrameUtil.AddMessageEventFilter (moved in 11.2.7). Classic still has the global. Code picks whichever exists.
- Midnight secret values: chat authors are secret inside instances, some unit names/GUIDs can be secret. Every read goes through IsSecret/pcall. 12.1 no longer returns secret UnitName in active PvP matches.
- SetRaidTarget is protected in 12.0, so no auto raid marks.
- Friendly nameplates in PvE instances are forbidden to addons (since 7.2). GetNamePlateForUnit returns nil for them.
- Addons cannot stop casting on anyone. Marking is visual only.
- SavedVariables are per client (Retail, Classic, Forever separate), hence export/import.
- Forever may not honor nameplateShowFriends writes (reported by another addon author).

## Not yet verified in game
Code passes luac 5.1 syntax check and core logic was run against a stub. Never run in a live client. Check:
1. Right-click "Help or Not" entry on EllesmereUI unit frames (EUI may not use Blizzard Menu API).
2. Menu API availability on Classic Era (falls back to /hon add with a login message).
3. Marked only mode vs EllesmereUI's nameplate module (EUI may force its own friendly plate settings and re-show plates).
4. Hidden friendly plates possibly nudging enemy plates.
5. Hostile marking: mark a friend and duel them to test enemy plate stamps.
6. StaticPopup edit box accessor across clients (code tries GetEditBox, editBox, EditBox).
7. `/hon test` marks yourself as Griefer to preview frame stamps.

## CurseForge
Main category Chat & Communication; additional Unit Frames, Raid Frames, PvP. License All Rights Reserved. Source linked to GitHub, automatic packaging set to tagged commits (tag v1.0.0 for release, -beta suffix for beta). Webhook added in GitHub (`https://www.curseforge.com/api/projects/1715654/package?token=TOKEN`); ping returned 200 while the project was still under review. The first tagged push is the real test. First file should be uploaded by hand for moderator review. Logo is an original split check/X PNG (not a Blizzard asset).
