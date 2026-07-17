# Sound effects (Cuelume)

Interaction sound effects are synthesized client-side via [Cuelume](https://cuelume-site.pages.dev/)
(`assets/js/app.js`), a zero-dependency Web Audio library. No audio files ship with the app.

Global setup lives in `assets/js/app.js`:

```js
import {bind, play, setEnabled} from "cuelume"

setEnabled(document.documentElement.dataset.soundEnabled !== "false")
bind()
window.addEventListener("phx:set-sound-enabled", ({detail: {enabled}}) => setEnabled(enabled))
window.addEventListener("phx:play-sound", ({detail: {sound}}) => play(sound))
```

`bind()` runs once and delegates listeners across the whole document — it picks up new elements
added later by LiveView patches automatically. Never call `bind()` again per-component.

## Declarative: sound on direct user interaction

Add a `data-cuelume-*` attribute straight to the element. Works on `<.button>`, `<.input>`, raw
`<button>`/`<a>` — HEEx `:global` attrs forward `data-*` through function components automatically.

```heex
<button data-cuelume-press>Save</button>
<button data-cuelume-toggle="bloom">Add to wantlist</button>
<.input field={@form[:enabled]} type="checkbox" data-cuelume-toggle="chime" />
```

| Attribute | Fires on | Default sound |
|---|---|---|
| `data-cuelume-hover` | pointerenter (fine pointer only) | `chime` |
| `data-cuelume-press` | pointerdown | `press` |
| `data-cuelume-release` | pointerup | `release` |
| `data-cuelume-toggle` | click | `toggle` |

Leave the attribute value empty for the default sound, or set it to any name from the palette:
`chime`, `sparkle`, `droplet`, `bloom`, `whisper`, `tick`, `press`, `release`, `toggle`, `success`,
`error`, `page`, `loading`, `ready`.

Use this when the sound should just confirm "you clicked something" — no server round-trip needed.

## Imperative: sound on a server-confirmed outcome

Push `"phx:play-sound"` from any LiveView `handle_event`/`handle_info` when the sound must reflect
an actual result (a save that really succeeded, an error that really happened) rather than a raw
click:

```elixir
socket
|> assign(:in_wantlist, true)
|> push_event("phx:play-sound", %{sound: "success"})
```

`push_event/3` is already in scope via `use PremiereEcouteWeb, :live_view`. Only use this path when
declarative click-sound isn't enough — it requires the socket to be `connected?/1`, so it cannot
fire from a disconnected initial render or reliably from `mount/3` on a fresh page load: browsers
block `AudioContext` playback until the user has produced a gesture (click/tap/keypress) somewhere
on the page. A "play a sound the instant a page loads" mount hook will silently do nothing on a
cold tab/hard refresh — don't add one.

## User preference

Sound effects are gated by `sound_effects_enabled` (default `true`) on the embedded
`PremiereEcoute.Accounts.User.Profile` schema (`lib/premiere_ecoute/accounts/user/profile.ex`),
toggled from the Preferences form in `AccountLive` (`/account`). No migration needed when adding
fields here — `profile` is a single embedded/JSON column.

- Initial page load: `get_sound_effects_enabled/1` in `lib/premiere_ecoute_web/layouts/layouts.ex`
  renders `data-sound-enabled` on `<html>` (`root.html.heex`), read once by `app.js` at boot.
- Live updates: `AccountLive` pushes `"phx:set-sound-enabled"` with `%{enabled: boolean}` after
  saving the profile, same pattern as the existing `"phx:set-theme"` push for color scheme.

Any handler that plays a sound imperatively does **not** need to check this preference itself —
`setEnabled(false)` makes `play()` a global no-op, so `push_event("phx:play-sound", ...)` is always
safe to call unconditionally.
