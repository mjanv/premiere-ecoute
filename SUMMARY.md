# Session Summary — 2026-02-19

## Task

Display track times on the radio page (`/radio/:username/:date`) in the streamer's local timezone instead of UTC, and allow users to set their timezone in account preferences (`/users/account`).

## Changes

### `lib/premiere_ecoute/accounts/user/profile.ex`
- Added `timezone` string field (default `"UTC"`) to the `Profile` embedded schema
- Updated `@type t` to include `timezone: String.t()`
- Added `:timezone` to the `cast/2` call in `changeset/2`
- Added `validate_timezone/1` private function using `Timex.Timezone.exists?/1`

### `lib/premiere_ecoute_web/live/accounts/account_live.html.heex`
- Added a timezone `<select>` dropdown (full-width, below Color Scheme) to the Preferences form
- Includes ~35 common IANA timezones across Europe, Americas, Asia, Pacific, and Africa

### `lib/premiere_ecoute_web/live/radio/viewer_live.ex`
- Reads `user.profile.timezone` (falls back to `"UTC"`) and assigns it to the socket as `@timezone`

### `lib/premiere_ecoute_web/live/radio/viewer_live.html.heex`
- Updated time display: `track.started_at |> DateTime.shift_zone!(@timezone) |> Calendar.strftime("%H:%M")`

## Design decisions

- **Whose timezone?** The streamer's timezone is used on the radio page (not the viewer's), since the page is public and may be viewed without authentication.
- **No migration needed** — `profile` is stored as JSONB; rows without the field default to `"UTC"` at the application level.
- **Validation** — Invalid timezone strings are rejected via `Timex.Timezone.exists?/1`, which is already a project dependency.
