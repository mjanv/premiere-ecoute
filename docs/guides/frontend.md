# 🎨 Frontend & Design System guide

## Tech stack

- [Tailwind CSS v4](https://tailwindcss.com) — utility-first CSS
- [daisyUI](https://daisyui.com/components/) — component layer on top of Tailwind
- [Phoenix Storybook](https://github.com/phenixdigital/phoenix_storybook) — component catalog at `/storybook`
- [Heroicons](https://heroicons.com) — icon set, available via `<.icon name="hero-*" />`

---

## Token system

Two layers coexist — do not mix them up.

### 1. Fixed dark palette (`assets/css/base/colors.css`)

CSS custom properties with hardcoded values. Used by **always-dark chrome**: sidebar, header, drawer, panel, and any inline `style=` attribute in templates.

```css
--color-dark-900   /* deepest backgrounds */
--color-dark-800   /* elevated surfaces (cards inside dark chrome) */
--color-dark-700   /* borders, dividers */
--color-dark-300   /* body text */
--color-primary-600  /* brand purple */
--color-primary-400  /* lighter purple, links */
--gradient-primary   /* purple→pink horizontal gradient */
```

**Rule:** use these vars when the element is intentionally dark regardless of the active theme (sidebar nav items, header bar, drawers, panels).

### 2. daisyUI semantic tokens

Defined by the `@plugin "../vendor/daisyui-theme"` blocks in `assets/css/app.css`. These adapt to the active theme (light/dark).

Key tokens:

| Token | Usage |
|---|---|
| `--color-base-100/200/300` | Page and card backgrounds |
| `--color-base-content` | Body text |
| `--color-primary` / `--color-primary-content` | Brand accent, CTA buttons |
| `--color-neutral` | Borders, dividers in content areas |
| `--color-error/success/warning/info` | Semantic state colors |

In Tailwind classes: `bg-base-200`, `text-base-content`, `border-neutral`, `bg-primary`, `text-error`, etc.

**Rule:** use these tokens in content-area components (`Card`, `EmptyState`, modal body, form inputs) — anything that should adapt when the theme switches.

### Semantic surface classes (`backgrounds.css`, `effects.css`)

Pre-built utility classes that bridge the two layers for common patterns:

```css
/* backgrounds */
.bg-surface           /* base-300 */
.bg-surface-elevated  /* base-200 */
.bg-surface-card      /* between base-200 and base-300 */
.bg-surface-interactive /* neutral */

/* borders */
.border-surface        /* neutral */
.border-surface-light  /* neutral/80 */

/* text */
.text-surface          /* base-content */
.text-surface-muted    /* base-content/50 */
.text-surface-bright   /* base-content */
.text-surface-primary  /* base-content */

/* hover */
.hover-surface:hover         /* neutral bg */
.hover-surface-elevated:hover /* neutral bg */
```

---

## Component auto-imports

Every LiveView and component module gets these imports for free via `html_helpers()` in `premiere_ecoute_web.ex` — no explicit `import` needed:

| Module | Functions |
|---|---|
| `CoreComponents` | `button`, `flash`, `icon`, `input`, `table`, `header`, `list`, `simple_form` + delegates below |
| `CoreComponents` (delegates) | `activity_card`, `album_display`, `track_display`, `playlist_display`, `page_header`, `status_badge`, `loading_spinner`, `skeleton_element`, `loading_overlay` |
| `Components.Images` | `cover`, `avatar` |
| `Components.Modal` | `modal`, `show_modal`, `hide_modal` |
| `Components.Backgrounds` | `gradient_bg` |
| `Components.Card` | `card` |
| `Components.EmptyState` | `empty_state` |
| `Components.MediaCard` | `media_card` |
| `Components.StatsCard` | `stats_card` |

Components **not** auto-imported (import per-module when needed): `Search`, `Drawer`, `WikipediaDrawer`, `Navigation.Back`, `Navigation.DayNav`, `AlbumTrackDisplay` (direct).

---

## Button component

`<.button>` is auto-imported everywhere via `CoreComponents`. Use it for all interactive buttons and link-buttons.

```heex
<.button>Default (primary soft)</.button>
<.button variant="primary">Primary</.button>
<.button variant="secondary">Secondary</.button>
<.button variant="ghost">Ghost</.button>
<.button variant="outline">Outline</.button>
<.button variant="danger">Delete</.button>
<.button variant="icon" aria-label="Close"><.icon name="hero-x-mark" /></.button>

<%!-- Sizes --%>
<.button size="xs">Tiny</.button>
<.button size="sm">Small</.button>
<.button>Medium (default)</.button>
<.button size="lg">Large</.button>

<%!-- As a link --%>
<.button navigate={~p"/sessions"}>Sessions</.button>
<.button href="https://spotify.com" target="_blank">Open Spotify</.button>
```

**Rule:** never use raw `<button class="bg-... px-... py-...">` for action buttons. Always use `<.button>` with a variant. The only acceptable raw `<button>` is for highly custom interactions where the daisyUI `btn` base class would conflict (e.g. toggle switches, carousel dots).

---

## Media card component

`<.media_card>` is auto-imported everywhere. Use it for all square image grid items — albums, artists, singles, playlists.

```heex
<%!-- Basic album card --%>
<.media_card
  src={album.cover_url}
  alt={album.name}
  title={album.name}
  subtitle={album.artist}
  navigate={~p"/discography/albums/\#{album.slug}"}
/>

<%!-- With badge (review count) --%>
<.media_card src={album.cover_url} alt={album.name} title={album.name} navigate={...}>
  <:badge :if={@count > 0}>
    <.icon name="hero-pencil" class="w-3 h-3" />{@count}
  </:badge>
</.media_card>

<%!-- Artist (circle shape, placeholder initials) --%>
<.media_card
  src={Artist.image_url(artist, 320)}
  alt={artist.name}
  title={artist.name}
  shape="circle"
  placeholder_class="bg-purple-900/30 border border-purple-500/20"
  navigate={~p"/discography/artists/\#{artist.slug}"}
>
  <span class="text-4xl font-bold text-purple-300">
    {String.upcase(String.first(artist.name || "?"))}
  </span>
</.media_card>
```

**Attrs:** `src`, `alt` (required), `title` (required), `subtitle`, `navigate`, `href`, `shape` (`square`|`circle`), `placeholder_class`, `class`
**Slots:** `:badge` (bottom-right overlay), `:overlay` (full hover overlay), inner block (placeholder content when no `src`)

---

## Modal component

The `<.modal>` component (`lib/premiere_ecoute_web/components/cards/modal.ex`) has two variants.

### JS-state (no server round-trip)

Show/hide without touching LiveView assigns. Use for purely presentational dialogs.

```heex
<%!-- Trigger --%>
<.button phx-click={show_modal("my-modal")}>Open</.button>

<%!-- Modal (always in DOM, hidden by default) --%>
<.modal id="my-modal">
  <:header>Title</:header>
  <p>Content</p>
  <:footer>
    <.button phx-click={hide_modal("my-modal")}>Close</.button>
  </:footer>
</.modal>
```

### Server-state (controlled by assign)

Use when the modal content depends on server data (selected record, form state, etc.).

```heex
<%= if @show_modal do %>
  <.modal id="detail-modal" show on_cancel="close_modal">
    <:header>Record Details</:header>
    <p>{@selected_record.name}</p>
    <:footer>
      <.button phx-click="close_modal">Close</.button>
      <.button phx-click="save" class="btn-primary">Save</.button>
    </:footer>
  </.modal>
<% end %>
```

**Attrs:**

| Attr | Type | Default | Description |
|---|---|---|---|
| `id` | string | required | Used for DOM targeting |
| `show` | boolean | `false` | Server-state: render as visible |
| `on_cancel` | JS or string | auto | JS command or event name to fire on close |
| `size` | string | `"md"` | `sm md lg xl xxl full` |
| `class` | string | — | Extra classes on the content box |

**Slots:** `:header`, `:inner_block` (required), `:footer`

**Rule:** never write a raw `<div class="fixed inset-0 ... z-50">` modal shell. Always use `<.modal>`.

---

## Development workflow

### Adding a new component

1. Create the module in the appropriate subdirectory under `lib/premiere_ecoute_web/components/`
2. If it should be universally available, add an `import` in `html_helpers()` in `premiere_ecoute_web.ex` and an entry in the `Boundary` exports list
3. Add a `.story.exs` file under `storybook/` to document it
4. Use daisyUI semantic tokens in the component — not the fixed dark palette vars

### Storybook

Visit [http://localhost:4000/storybook](http://localhost:4000/storybook) during development to browse and test components in isolation. Stories live in `storybook/`.

### CSS files

```
assets/css/
├── app.css                    # Entry point: imports, daisyUI plugin + themes
├── base/
│   ├── colors.css             # Fixed dark palette vars + gradient definitions
│   └── typography.css         # Font stack, weight utilities
└── components/
    ├── backgrounds.css        # .bg-surface-* utilities + gradient classes
    ├── buttons.css            # .btn-primary / .btn-secondary overrides
    ├── effects.css            # .border-surface-*, .text-surface-*, .hover-surface-*
    └── sidebar.css            # Sidebar-specific styles
```
