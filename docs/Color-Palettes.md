# Color Palettes

Fancychat keeps a per-mode color palette covering every chat category (Tell, Party, Linkshell, Shout, Emote, Combat, NPC, etc.) plus auxiliary colors for damage classifications, actor highlights, and special tags.

## Editing colors

Open **Settings → Font Colors**. Each editable color is shown as a small swatch with a label.

1. Click a swatch to bring up the **Color Picker** in the right pane.
2. Adjust the color in the picker.
3. Click the **arrow button** next to a swatch to apply the picker's current color to that swatch.

Hover the small **(i)** icons next to each label for a description of which messages use that color.

The **Reset Colors** button restores the entire palette to the addon defaults.

## Sharing palettes

Fancychat treats colorsets as named files you can save, import, and share freely. The export/import flow is dialog-based, so you can keep several different palettes per character (e.g. one for combat-heavy events, one for social play) and swap between them on demand.

### Export

1. Click **Export Colors**. A dialog appears with a **Filename** field.
2. The filename is pre-filled with a suggestion based on your character name: `colorset_<your character>_1`, `colorset_<your character>_2`, etc. (auto-incrementing — Fancychat won't suggest a name that's already in use).
3. Edit the filename if you want something more descriptive (e.g. `colorset_Eleanor_combat` or `colorset_party_friendly`).
4. Click **Save**. The file is written to:

```
addons/fancychat/chatcolors/<filename>
```

The `chatcolors/` subfolder is created automatically the first time you export. The file format is one `key,value` line per color slot, where the value is a hex ARGB number.

Example file contents:
```
tell,0xffd35aff
party,0xff66e7fe
combat,0xffdcf1fc
...
```

Plain text means it can be inspected, edited in any text editor, or shared.

### Import

1. Click **Import Colors**. A dialog appears with a list of **every** `.txt`-less colorset file currently in `addons/fancychat/chatcolors/` — yours, other characters', or ones you've dropped in from elsewhere.
2. Click an entry in the list to select it.
3. Click **Load**. Fancychat replaces your current palette with the colors in that file.

Missing values in the file fall through to the addon defaults — useful if a friend exports their palette before a new color slot existed.

### Sharing across characters or with another player

Because Import lets you load any file in the folder, sharing is as simple as **copying the file in**:

- **Same player, different character** — open `chatcolors/` and you'll see all your saved colorsets; from any character, just hit Import and pick the one you want.
- **Receive a palette from another player** — drop their `colorset_*` file into your `chatcolors/` folder, open Settings → Font Colors → Import Colors, and pick it from the list. No renaming required.

## See also

- [Settings Reference → Font Colors](Settings-Reference.md#font-colors) — the Settings UI walkthrough
- [Data Storage](Data-Storage.md#color-sets) — where the file lives on disk
- [Compact Combat Log](Compact-Combat-Log.md#actor-name-colouring) — actor-specific color slots
