# Wowhead Lookup

Gives you the Wowhead link for an item, spell, quest, achievement, currency or NPC, ready to copy into your browser.
Addons can't open a browser, so the link is shown selected in a box: press **Ctrl+C** (the box closes) and paste it.

Retail (Interface 120100) and WoW: Forever (Interface 16001, linking to Wowhead's Classic pages).

## Use

- **A key for what you're hovering:** set it in Options > Keybindings > AddOns > Wowhead Lookup. It links whatever's
  in the tooltip (in your bags, action bars, quest log, achievements, a chat link you've clicked open, an NPC in the
  world...). Anything else with a name in its tooltip is searched for by that name.
- **`/wiki`** (or `/wowhead`) followed by a link (shift-click an item, spell, quest or achievement into the chat box)
  or a search term: `/wiki Thunderfury`. With nothing after it, it links your target.

Inside dungeons and raids retail hides NPCs from addons, so NPCs can't be linked there (use `/wiki <name>`).

## Install

`scripts\install-local.ps1 -AddOnsPath <Interface\AddOns>` copies the addon into a client for testing (retail by
default).
