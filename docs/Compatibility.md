# Compatibility

> **TL;DR:** Fancychat is **not designed** to run alongside other addons that modify, reformat, or recolour incoming chat messages — it won't be changed on its side to make them work. A few may happen to coexist anyway; you can try your luck by loading **FancyChat last** in your Ashita default script.

## What is NOT supported alongside Fancychat

Combat-log enhancers and chat replacements that intercept or rewrite the chat stream are **unsupported** out of the box:

- `simplelog` — combat-line reformatter
- Alternative chat-replacement add-ons
- Anything else that reformats, colourises, or otherwise rewrites incoming chat messages before you see them

Running two chat-handling add-ons at the same time can produce visual conflicts:

- Duplicated lines (each addon adds its own copy)
- Broken colours (palette escapes from one addon get overwritten by the other)
- Mangled formatting, missing spaces between coloured segments
- Tabs that don't match the messages they should contain

These are **not configurations Fancychat tries to recover from** — there's no "compatibility mode", and the code won't be changed to accommodate them.

## You can still try your luck

Some other chat-touching add-ons may happen to coexist fine — Fancychat just won't make any promises. If you want to find out:

1. Add both add-ons to your Ashita default script, with **FancyChat listed last** so it gets the final pass over the chat stream.
2. Play normally and watch for the visual conflicts listed above.
3. If you don't see any, you got lucky. If you do, unload the other add-on (or unload Fancychat) and move on.

## What DOES work alongside Fancychat

Everything that doesn't touch the chat stream is fine — UI overlays, equipment swap addons, stats tracking, mob trackers, music players, etc. Fancychat coexists with anything that doesn't intercept incoming chat.

## How to switch

If you have other chat addons loaded already and want to use Fancychat:

```
/addon unload simplelog
/addon unload <other chat addon>
/addon load fancychat
```

If you want to switch back to a different chat addon:

```
/addon unload fancychat
/addon load simplelog
```

Update your Ashita default-load script accordingly so the change persists across game launches.

## See also

- [Installation](Installation.md) — getting Fancychat loaded in the first place
- [Troubleshooting](Troubleshooting.md) — what to do if things look wrong after load
