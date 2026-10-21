# Wowhead Lookup

Gives you the Wowhead link for an item, spell, quest, achievement, currency or NPC, ready to copy into your browser.
Addons can't open a browser, so the link is shown selected in a box: press **Ctrl+C** (the box closes) and paste it.

Retail (Interface 120100) and WoW: Forever (Interface 16001, linking to Wowhead's Classic pages).

## Use

- **A key for what you're hovering:** set it in Options > Keybindings > AddOns > Wowhead Lookup. It links whatever's
  in the tooltip (in your bags, action bars, achievements, a chat link you've clicked open, an NPC in the
  world...), quests in the quest log, on the map, in the objective tracker and at quest givers, and achievements in the
  tracker and the Achievements window, and in the Collections window mounts, pets (their NPC's page), appearances (the
  item named in the tooltip; Tab picks another) and the items in a set. Anything else with a name in its tooltip is
  searched for by that name.
- **`/wiki`** (or `/wowhead`) followed by a link (shift-click an item, spell, quest or achievement into the chat box)
  or a search term: `/wiki Thunderfury`. With nothing after it, it links your target.

Where the game hides an ID from addons (NPCs in dungeons and raids, on retail), it searches by the name instead.

## Install

`scripts\install-local.ps1 -AddOnsPath <Interface\AddOns>` copies the addon into a client for testing (retail by
default).
