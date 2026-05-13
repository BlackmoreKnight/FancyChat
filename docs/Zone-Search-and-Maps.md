# Zone Search & Maps

Fancychat ships with a built-in zone-action popup and an offline collection of FFXI zone maps. **Hold Ctrl and left-click any chat line that mentions a recognised zone name** to open the popup at the cursor.

## What the popup shows

For every zone detected on the chat line, the popup lists three top-level actions followed by a collapsible map browser.

### Top-level actions

- `/sea "Zone Name"` — runs the standard FFXI zone-search command for that zone. Quoting handles multi-word zones like `Rolanberry Fields` or `Ru'Lude Gardens`.
- **Open Zone on FFXIclopedia** — opens the zone's FFXIclopedia page in your default browser.
- **Open Zone on bg-wiki** — same, for bg-wiki. Useful when FFXIclopedia is unreachable for you (Cloudflare sometimes blocks Fandom-hosted wikis on certain VPNs).

### Map browser

Below the three actions is an accordion with one section per available map type. Empty sections are hidden, so you only see what's actually available for that zone.

Sections appear in this order:

| Section | What it contains |
|---|---|
| **Maps** | The zone's base floor / area maps |
| **Treasure** | Coffer-spawn and chest-spawn maps |
| **Fishing** | Fishing-spot maps showing what catches where |
| **Weather** | Elemental-spawn maps, organised by weather type |
| **Notorious Monsters** | One entry per NM, labelled with the monster's name (not the filename). NMs that share the same map still get their own clickable entry. |

Each section is collapsed by default (the heading shows `+`) or expanded (the heading shows a green `-`). The accordion only keeps **one** section open at a time — opening a section automatically collapses whichever was open before. Click the green `-` to collapse the current section without opening another.

Click any map entry to open it in a new window with the zone and entry name in the title. The window starts at about 70% of your display height and the image is scaled to fit while keeping its aspect ratio. Drag the bottom-right corner to resize — the image rescales with the window. Multiple maps can be open at once; each closes independently with its X button.

Zones that don't have any local maps still show a single "Maps" section expanded with a greyed-out `(No Map)` placeholder so the popup layout stays consistent.

## Dismissing the popup

The popup grows up-and-right from the click point and stays anchored even if you move the mouse. Dismiss it by:

- Clicking anywhere outside it
- Pressing Escape
- Choosing any of its entries

Each fresh open resets the accordion, so the **Maps** section is always pre-expanded when the popup re-opens.

## Adding your own maps

Map files live under:

```
Ashita/addons/fancychat/maps/<Zone Name>/<Section>/
```

Where `<Section>` is one of: `Maps`, `Treasure`, `Fishing`, `Weather`, `Notorious_Monsters`.

Drop a PNG or JPEG into the appropriate subfolder and it'll be picked up the next time you open the popup for that zone — no addon reload required.

### Notorious Monster labelling

The `Notorious_Monsters/` folder uses a small `_nm_index.lua` file to map each image filename to the NM name shown in the popup. Hand-edit it if you want to fix a wiki typo, rename an entry, or add a label for a map you've dropped in.

## See also

- [The Chat Window → Copying & saving lines](The-Chat-Window.md#copying--saving-lines) — the rest of the click / Shift-click / Ctrl-click interactions
- [Data Storage](Data-Storage.md) — where the maps folder sits in the addon directory
