# Wikipedia API: Extractable Data for Music Pages

> Reference document for music artist and album data extraction.
> Tested against: [BTS](https://en.wikipedia.org/wiki/BTS) and [Arirang (album)](https://en.wikipedia.org/wiki/Arirang_(album)).

---

## TL;DR — Recommended fetch strategy

**Minimum viable (display card):**
```
GET https://en.wikipedia.org/api/rest_v1/page/summary/{title}
```
→ check `type`, extract `description`, `extract`, `thumbnail`, `wikibase_item`

**Rich artist profile:**
1. REST summary (above)
2. `GET /api/rest_v1/page/media-list/{title}` — full image gallery
3. `GET https://www.wikidata.org/wiki/Special:EntityData/{Q-ID}.json` → P136 (genre), P1902 (Spotify ID), P571 (formation), P527 (members), P434 (MusicBrainz), P2002/P2003 (social)

**Rich album profile:**
1. REST summary (above)
2. `GET /api/rest_v1/page/media-list/{title}` → `items[0]` where `section_id == 0` is the album cover
3. Wikidata → P577 (release date), P175 (performer), P264 (label), P136 (genre), P436 (MusicBrainz release group), P1954 (Discogs), P1712 (Metacritic)

**Section-by-section content:**
1. `GET /w/api.php?action=parse&page={title}&prop=tocdata&format=json` — full TOC with all section indexes
2. `GET /w/api.php?action=parse&page={title}&section=N&prop=text&format=json` — rendered HTML for section N only (~5–20 KB vs ~200 KB for the full page)

**Infobox (structured fields):**
- Preferred: Wikidata (structured, no parsing)
- Fallback wikitext: `GET /w/api.php?action=query&prop=revisions&rvprop=content&rvslots=main&titles={title}&format=json` → regex-extract `{{Infobox album\n...\n}}` from `query.pages[id].revisions[0].slots.main["*"]`

**Avoid** `action=parse&prop=wikitext` for structured data — Wikidata gives the same fields without regex-parsing wikitext templates.

**Multi-language:**
1. Fetch English summary to get `wikibase_item` (Q-ID)
2. `GET https://www.wikidata.org/wiki/Special:EntityData/{Q-ID}.json` → `entities[Q].sitelinks.{lang}wiki.title` — canonical title in target language
3. `GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}` — summary in that language
4. Fallback to English if `sitelinks.{lang}wiki` is absent

---

## 1. REST API v1 — `/page/summary/{title}`

**Base URL:** `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
- No auth required. Add `User-Agent` header.
- Transparently follows redirects (`Bangtan_Boys` → BTS page).
- Accepts underscored titles (`Arirang_(album)`) or URL-encoded form.

### Fields

| JSON path | Type | Artist | Album | Notes |
|---|---|---|---|---|
| `type` | string | `"standard"` | `"standard"` | **Check first.** `"disambiguation"` means wrong page. |
| `title` | string | `"BTS"` | `"Arirang (album)"` | MediaWiki stored title |
| `displaytitle` | string (HTML) | `"BTS"` | `"<i>Arirang</i> (album)"` | May contain HTML `<i>`, `<b>` |
| `description` | string | `"South Korean boy band"` | `"2026 studio album by BTS"` | High-value short label for display |
| `description_source` | string | `"local"` | `"local"` | `"local"` or `"central"` (Wikidata) |
| `wikibase_item` | string | `"Q13580495"` | `"Q137787331"` | Wikidata Q-ID — bridge to structured data |
| `pageid` | int | `39862325` | `82124511` | Stable internal Wikipedia ID |
| `extract` | string | present | present | First paragraph, plain text — safe for display |
| `extract_html` | string (HTML) | present | present | First paragraph with `<p>`, `<b>` tags |
| `thumbnail.source` | URL | present | present | Resized thumbnail (~330px). **Null-check** — absent on stub pages. |
| `thumbnail.width` | int | `330` | `300` | |
| `thumbnail.height` | int | `130` | `300` | |
| `originalimage.source` | URL | present | present | Full-resolution source |
| `originalimage.width` | int | `1980` | `300` | |
| `originalimage.height` | int | `777` | `300` | |
| `titles.canonical` | string | `"BTS"` | `"Arirang_(album)"` | URL-safe (underscores) |
| `titles.normalized` | string | `"BTS"` | `"Arirang (album)"` | Human-readable (spaces) |
| `content_urls.desktop.page` | URL | present | present | Canonical desktop URL |
| `content_urls.mobile.page` | URL | present | present | Mobile URL |
| `timestamp` | ISO 8601 | present | present | Last edit time |
| `revision` | string | present | present | Current revision ID |
| `lang` | string | `"en"` | `"en"` | Language edition |

**Notes:**
- Album `description` consistently follows the pattern `"{year} {type} album by {artist}"` — reliable for type classification.
- `thumbnail` / `originalimage` are absent for stub or image-less articles.

---

## 2. REST API v1 — `/page/media-list/{title}`

**Base URL:** `https://en.wikipedia.org/api/rest_v1/page/media-list/{title}`

Top-level: `revision`, `tid`, `items[]`

### Per-item fields

| JSON path | Type | Present | Description |
|---|---|---|---|
| `items[n].title` | string | always | `File:Filename.jpg` — Wikimedia Commons filename |
| `items[n].leadImage` | bool | always | Unreliable — check `section_id == 0` instead |
| `items[n].section_id` | int | always | `0` = lead section (best proxy for cover/hero image) |
| `items[n].type` | string | always | `"image"`, `"video"`, `"audio"` |
| `items[n].showInGallery` | bool | always | Safe to use for gallery filtering |
| `items[n].caption.html` | string | if captioned | Caption with wikilinks as HTML |
| `items[n].caption.text` | string | if captioned | Plain-text caption |
| `items[n].srcset[n].src` | URL | images | Protocol-relative (`//upload.wikimedia…`) — prepend `https:` |
| `items[n].srcset[n].scale` | string | images | `"1x"`, `"1.5x"`, `"2x"` |

**Notes:**
- Artist pages return many items (20+); album pages return very few (1–3 for Arirang).
- `items[0]` where `section_id == 0` is the album cover on album pages.
- `srcset` URLs are protocol-relative — always prepend `https:` before use.
- `leadImage` was `false` even for the BTS hero image — do not rely on it.

---

## 3. MediaWiki Action API — `prop=extracts`

**Endpoint:** `https://en.wikipedia.org/w/api.php`
**Params:** `action=query&prop=extracts&exintro=true&titles={title}&format=json`

| JSON path | Type | Description |
|---|---|---|
| `query.pages.{pageid}.extract` | string (HTML) | Full intro section (all paragraphs before first heading) |

**Useful params:**
- `exintro=true` — intro only (vs full article)
- `explaintext=true` — plain text instead of HTML
- `exsentences=N` — limit to N sentences

**vs REST summary `extract`:** The action API returns the complete intro (all paragraphs), while REST returns only the first paragraph. BTS: substantially more content.
**Warning:** HTML may be malformed. Sanitize before rendering. Prefer `explaintext=true` when displaying.

---

## 4. MediaWiki Action API — `prop=pageimages`

**Endpoint params:** `action=query&prop=pageimages&piprop=original&titles={title}&format=json`

| JSON path | Type | Artist (BTS) | Album (Arirang) | |
|---|---|---|---|---|
| `query.pages.{pageid}.original.source` | URL | present | **absent** | Only freely-licensed images |
| `query.pages.{pageid}.original.width` | int | `1980` | **absent** | |
| `query.pages.{pageid}.original.height` | int | `777` | **absent** | |

**Critical:** `piprop=original` only returns freely-licensed (Commons) images. Album covers are typically fair-use images hosted on en.wikipedia.org, so this returns nothing for most albums. **Use `media-list` for album covers.** Use `piprop=thumbnail&pithumbsize=500` as a safer alternative.

---

## 5. MediaWiki Action API — `prop=pageprops`

**Endpoint params:** `action=query&prop=pageprops&titles={title}&format=json`

| JSON path | Type | Artist | Album | Notes |
|---|---|---|---|---|
| `pageprops.wikibase_item` | string | `"Q13580495"` | `"Q137787331"` | Consistent secondary way to get Wikidata ID |
| `pageprops.wikibase-shortdesc` | string | `"South Korean boy band"` | `"2026 studio album by BTS"` | Same as REST `description` |
| `pageprops.displaytitle` | string (HTML) | absent | `"<i>Arirang</i> (album)"` | Only when display differs from stored title |
| `pageprops.page_image_free` | string | present | absent | Filename of freely-licensed lead image |
| `pageprops.page_image` | string | absent | `"BTS_-_Arirang_(cover).png"` | Lead image filename (may be non-free) |

**Note:** `page_image_free` and `page_image` are mutually exclusive in practice.

---

## 6. MediaWiki Action API — `prop=categories`

**Endpoint params:** `action=query&prop=categories&titles={title}&format=json&cllimit=500`

| JSON path | Type | Description |
|---|---|---|
| `query.pages.{pageid}.categories[n].title` | string | e.g. `"Category:2026 albums"` |
| `continue.clcontinue` | string | Continuation token if truncated |

**Useful category patterns for classification:**

| Pattern | Interpretation |
|---|---|
| `Category:{YYYY} albums` | Release year |
| `Category:{Language}-language albums` | Primary album language |
| `Category:Albums by {artist}` | Artist linkage |
| `Category:Albums produced by {producer}` | Producer credits |
| `Category:{Genre} albums` | Genre tag |
| `Category:South Korean musical groups` | Nationality (artist pages) |

**Notes:**
- BTS has 100+ categories. Use `cllimit=500` and follow `continue` tokens.
- Filter out maintenance categories: `CS1`, `Articles`, `All articles`, `Wikipedia`, `Pages using`.
- Album pages have cleaner, more semantic categories.

---

## 7. MediaWiki Action API — `prop=revisions`

**Endpoint params:** `action=query&prop=revisions&rvprop=ids|timestamp|user|size&titles={title}&format=json`

| JSON path | Type | Description |
|---|---|---|
| `query.pages.{pageid}.revisions[0].revid` | int | Current revision ID |
| `query.pages.{pageid}.revisions[0].timestamp` | ISO 8601 | Last edit time |
| `query.pages.{pageid}.revisions[0].user` | string | Username of last editor |
| `query.pages.{pageid}.revisions[0].size` | int | Article size in bytes (proxy for depth: BTS=272k, Arirang=39k) |

---

## 8. Wikidata Entity API

**Endpoint:** `https://www.wikidata.org/wiki/Special:EntityData/{Q-ID}.json`
**Response root:** `entities.{Q-ID}`

### Common fields

| JSON path | Description |
|---|---|
| `labels.en.value` | English name |
| `descriptions.en.value` | English short description |
| `aliases.en[n].value` | Alternative names |
| `sitelinks.enwiki.title` | Wikipedia page title |
| `sitelinks.{lang}wiki.title` | Title in other language editions |
| `claims` | Property map keyed by P-IDs |

### Artist properties (example: BTS — Q13580495)

| P-ID | Label | Value type | Example |
|---|---|---|---|
| `P31` | instance of | entity | `Q216337` (music group) |
| `P571` | inception/formation | time | `+2013-06-13T00:00:00Z` |
| `P495` | country of origin | entity | `Q884` (South Korea) |
| `P740` | location of formation | entity | `Q8684` (Seoul) |
| `P136` | genre | entity (multiple) | `Q213665` (K-pop) |
| `P264` | record label | entity (multiple) | `Q1988428` (Big Hit Music) |
| `P856` | official website | URL | `https://ibighit.com/` |
| `P527` | has members | entity (multiple) | 7 member Q-IDs |
| `P2124` | member count | quantity | `+7` |
| `P2936` | language used | entity | `Q9176` (Korean) |
| `P800` | notable works | entity (multiple) | Album Q-IDs |
| `P18` | image | string | Commons filename |
| `P434` | MusicBrainz artist ID | string | `0d79fe8e-...` |
| `P1902` | Spotify artist ID | string | `3Nrfpe0tUJi4K4DXYWgMUX` |
| `P1953` | Discogs artist ID | string | `5034422` |
| `P2850` | iTunes artist ID | string | `883131348` |
| `P2397` | YouTube channel ID | string | `UCLkAepWjdylmXSltofFvsYQ` |
| `P2002` | Twitter/X username | string | `bts_bighit` |
| `P2003` | Instagram username | string | `bts.bighitofficial` |
| `P2013` | Facebook ID | string | `bangtan.official` |
| `P3192` | Last.fm ID | string | present |

### Album properties (example: Arirang — Q137787331)

| P-ID | Label | Value type | Example |
|---|---|---|---|
| `P31` | instance of | entity | `Q482994` (studio album) |
| `P175` | performer | entity | `Q13580495` (BTS) |
| `P577` | publication date | time | `+2026-03-20T00:00:00Z` |
| `P264` | record label | entity | Big Hit Music |
| `P136` | genre | entity (multiple) | K-pop |
| `P162` | producer | entity (multiple) | Multiple producer items |
| `P291` | place of publication | entity | `Q884` (South Korea) |
| `P436` | MusicBrainz release group ID | string | `21159e3f-...` |
| `P1954` | Discogs master ID | string | `4169260` |
| `P1729` | AllMusic album ID | string | `mw0004753217` |
| `P1712` | Metacritic ID | string | `music/arirang/bts` |
| `P10135` | Apple Music album ID | string | present |
| `P3192` | Last.fm ID | string | `BTS/ARIRANG` |
| `P6217` | has tracklist | string | `Bts/Arirang` |

### Wikidata value type decoding

| Type | How to read |
|---|---|
| `wikibase-entityid` | `datavalue.value.id` → another Q-ID; resolve with another Wikidata call for its label |
| `time` | `datavalue.value.time` (ISO-like), `precision` (11=day, 10=month, 9=year) |
| `string` | `datavalue.value` directly |
| `monolingualtext` | `datavalue.value.{text, language}` |
| `quantity` | `datavalue.value.{amount, unit}` |

---

## 9. Disambiguation handling

The `type` field in the REST summary response is the single mandatory guard before any parsing:

| `type` value | Meaning | Action |
|---|---|---|
| `"standard"` | Normal article | Proceed |
| `"disambiguation"` | Disambiguation page | Prompt user or refine search |
| `"no-extract"` | Special/portal pages | Skip |

**Practical rules:**
1. Always check `type == "standard"` before parsing any other field.
2. For ambiguous titles, append the Wikipedia disambiguation suffix: `Arirang_(album)`, `Arirang_(song)`. Both underscored and URL-encoded forms work.
3. Redirects are transparently followed and the returned `title` / `wikibase_item` reflect the canonical destination.
4. The `normalized` array in action API responses confirms when a title was rewritten (underscores removed, etc.).

---

## 10. Full data availability matrix

| Data point | REST summary | media-list | extracts | pageimages | pageprops | revisions | Wikidata |
|---|---|---|---|---|---|---|---|
| Page ID | `pageid` | — | `pageid` | `pageid` | `pageid` | `pageid` | — |
| Wikidata Q-ID | `wikibase_item` | — | — | — | `wikibase_item` | — | entity key |
| Short description | `description` | — | — | — | `wikibase-shortdesc` | — | `descriptions.en.value` |
| Thumbnail (free) | `thumbnail` | `srcset` | — | `thumbnail` | — | — | P18 (filename) |
| Album cover | `thumbnail` | `items[0]` (sec 0) | — | **absent** (fair-use) | `page_image` (name) | — | — |
| Plain text extract | `extract` | — | `explaintext` | — | — | — | — |
| Full HTML intro | `extract_html` | — | `extract` | — | — | — | — |
| Last modified | `timestamp` | — | — | — | — | `timestamp` | — |
| Revision ID | `revision` | `revision` | — | — | — | `revid` | — |
| Article size | — | — | — | — | — | `size` | — |
| Page type guard | `type` | — | — | — | — | — | P31 |
| Genre | — | — | in text | — | — | — | **P136** |
| Release date | — | — | in text | — | — | — | **P577** |
| Record label | — | — | in text | — | — | — | **P264** |
| Performer/artist | — | — | in text | — | — | — | **P175** |
| Members | — | — | in text | — | — | — | **P527** |
| Formation date | — | — | in text | — | — | — | **P571** |
| Origin country | — | — | in text | — | — | — | **P495** |
| Official website | — | — | in text | — | — | — | **P856** |
| Spotify artist ID | — | — | — | — | — | — | **P1902** |
| MusicBrainz artist | — | — | — | — | — | — | **P434** |
| MusicBrainz release | — | — | — | — | — | — | **P436** |
| Discogs artist | — | — | — | — | — | — | **P1953** |
| Discogs album | — | — | — | — | — | — | **P1954** |
| Social media handles | — | — | — | — | — | — | P2002/P2003/P2013 |
| YouTube channel | — | — | — | — | — | — | **P2397** |
| Metacritic ID | — | — | — | — | — | — | **P1712** (album only) |
| AllMusic ID | — | — | — | — | — | — | **P1729** (album only) |
| Apple Music album | — | — | — | — | — | — | **P10135** (album only) |
| Last.fm ID | — | — | — | — | — | — | **P3192** |

---

## 11. Page sections — `action=parse&prop=tocdata`

**Endpoint:** `https://en.wikipedia.org/w/api.php`
**Params:** `action=parse&page={title}&prop=tocdata&format=json`

> `prop=sections` is deprecated since MediaWiki 1.46 — use `prop=tocdata`.

### Response structure

```json
{
  "parse": {
    "title": "BTS",
    "pageid": 39862325,
    "tocdata": {
      "entries": [...]
    }
  }
}
```

### Section entry fields

| Field | Type | Example | Description |
|---|---|---|---|
| `toclevel` | int | `1`, `2` | Nesting depth (1 = H2, 2 = H3) |
| `level` | string | `"2"`, `"3"` | Raw heading level |
| `line` | string | `"History"` | Section title (may contain HTML) |
| `number` | string | `"2"`, `"2.1"` | TOC number |
| `index` | string | `"3"` | Sequential index — use this with `section=N` |
| `fromtitle` | string | `"BTS"` | Source page (differs if from transcluded template) |
| `byteoffset` | int | `11075` | Byte offset in raw wikitext |
| `anchor` | string | `"History"` | URL fragment (spaces → underscores) |
| `linkAnchor` | string | `"History"` | Unicode-safe anchor variant |

**Section counts:** BTS = 36 sections, Arirang = 17 sections.

**Typical album section structure:**
```
1   Background and release    (toclevel:1)
2   Music and lyrics          (toclevel:1)
2.1   Songs                   (toclevel:2)
3   Promotion                 (toclevel:1)
3.1   Marketing               (toclevel:2)
3.2   Live performances       (toclevel:2)
4   Critical reception        (toclevel:1)
5   Commercial performance    (toclevel:1)
6   Track listing             (toclevel:1)
7   Personnel                 (toclevel:1)
7.1   Musicians               (toclevel:2)
7.2   Technical               (toclevel:2)
8   Charts                    (toclevel:1)
9   Release history           (toclevel:1)
10  References                (toclevel:1)
```

**Note:** duplicate section names get a numeric suffix on `anchor` (`Notes` → `Notes_2`).

### Fetching section content by index

**Params:** `action=parse&page={title}&section={index}&prop=text&format=json`

```json
{
  "parse": {
    "title": "BTS",
    "pageid": 39862325,
    "text": { "*": "<div class=\"mw-content-ltr mw-parser-output\">...</div>" }
  }
}
```

- Content lives at `parse.text["*"]` (note: asterisk key, not a named field).
- Section 0 = lead section (intro + infobox), `section=1` = first named section.
- **Per-section response is ~5–20 KB vs ~200 KB for the full page** — always prefer this for targeted extraction.
- Section 0 contains the infobox HTML (see section 12 below).

### Batch all sections efficiently

```
GET /w/api.php?action=parse&page={title}&prop=tocdata&format=json   → get all indexes
GET /w/api.php?action=parse&page={title}&section=0&prop=text        → lead + infobox
GET /w/api.php?action=parse&page={title}&section=N&prop=text        → each body section
```

Do not fetch `prop=text` without a `section=` param — the full 200 KB response is rarely needed.

---

## 12. Infobox extraction

### Approach 1 — Wikitext parsing (preferred for completeness)

**Endpoint params:** `action=query&prop=revisions&rvprop=content&rvslots=main&titles={title}&format=json`

Wikitext lives at:
```
query.pages[pageId].revisions[0].slots.main["*"]
```

This is equivalent to `action=parse&prop=wikitext` but uses the `query` module, allowing it to be combined with `prop=pageprops|info` in a single request.

#### Artist infobox — `{{Infobox musical artist}}`

| Parameter | Example | Notes |
|---|---|---|
| `name` | `BTS` | Display name |
| `image` | `BTS during a White House...jpg` | Commons filename |
| `caption` | text | Image caption |
| `alias` | Bangtan Boys, ... | `{{plainlist}}` wrapper — strip template |
| `origin` | `[[Seoul]], South Korea` | Strip wikilinks |
| `genre` | hip-hop, R&B, pop | `{{flatlist}}` — strip template |
| `years_active` | `2013–present` | |
| `label` | Big Hit, Columbia, ... | `{{flatlist}}` |
| `website` | `{{URL|ibighit.com/...}}` | Strip `{{URL|...}}` wrapper |
| `current_members` | RM, Suga, J-Hope, ... | `{{plainlist}}` with wikilinks |
| `module2` | `{{Infobox Chinese}}` | Nested template for romanizations |

#### Album infobox — `{{Infobox album}}`

| Parameter | Example | Notes |
|---|---|---|
| `name` | `Arirang` | Album title |
| `type` | `studio` | `studio`, `live`, `compilation`, `EP`, `single` |
| `artist` | `[[BTS]]` | Wikilinked — strip `[[...]]` |
| `cover` | `BTS - Arirang (cover).png` | Filename only (may be fair-use, not on Commons) |
| `released` | `March 20, 2026` | Not ISO — parse with date library |
| `recorded` | `July–November 2025` | Range, not a single date |
| `length` | `41:13` | Total runtime as `MM:SS` |
| `language` | `{{hlist|English|Korean}}` | Strip `{{hlist|...}}` wrapper |
| `producer` | `* [[Sarah Aarons]]\n* ...` | Bulleted list — split on `\n*` |
| `label` | `[[Big Hit Music|Big Hit]]` | `[[target|display]]` — take display part |
| `prev_title` | `[[Permission to Dance on Stage – Live]]` | Previous album in chronology |
| `prev_year` | `2025` | |
| `misc` | `{{Singles | name = ... }}` | Singles sub-template |

**Wikitext parsing rules:**
```
| field = value       → split on first =, trim whitespace
[[target|display]]   → take display part (after |), or target if no |
[[target]]           → take target directly
{{flatlist|...}}     → extract comma-separated items inside
{{hlist|a|b|c}}      → extract pipe-separated items
{{URL|url}}          → extract the url argument
* item\n             → split on \n* for bulleted lists
<ref>...</ref>       → strip entirely
```

Prefer Wikidata (section 9) over wikitext for structured fields whenever possible — `released` (P577), `label` (P264), `genre` (P136), `performer` (P175) are all cleaner as Wikidata properties.

### Approach 2 — HTML parsing (section 0)

**Params:** `action=parse&page={title}&section=0&prop=text&format=json`

The infobox renders as an HTML `<table>`:

```html
<table class="infobox vevent haudio">
  <tbody>
    <tr><th colspan="2" class="infobox-above summary album">Arirang</th></tr>
    <tr><td colspan="2" class="infobox-image">...</td></tr>
    <tr>
      <th class="infobox-label">Artist</th>
      <td class="infobox-data"><a href="/wiki/BTS">BTS</a></td>
    </tr>
    ...
```

| CSS class | Content |
|---|---|
| `table.infobox` | Infobox root — works for both artist and album |
| `table.infobox.vevent` | Album infobox specifically |
| `.infobox-above` | Title row |
| `.infobox-image` | Cover/photo |
| `div.infobox-caption` | Caption below image |
| `.infobox-label` | Field name (`th`) |
| `.infobox-data` | Field value (`td`) |

**HTML parsing is more fragile** than wikitext for field extraction — values contain nested `<a>`, `<span>`, `<ul>` markup and citation `<sup>` that must be stripped. Prefer wikitext or Wikidata over HTML scraping.

---

## 13. `api.php` vs REST API

| Capability | `api.php` (Action API) | REST API (`/api/rest_v1/`) |
|---|---|---|
| Page summary (extract + thumbnail + description) | No direct equivalent | `/page/summary/{title}` |
| Rendered page HTML | `action=parse&prop=text` (200 KB+) | `/page/html/{title}` — Parsoid HTML, cleaner |
| Per-section HTML | `action=parse&section=N&prop=text` | No equivalent |
| Section TOC | `action=parse&prop=tocdata` | No equivalent |
| Raw wikitext | `prop=wikitext` or `rvprop=content` | No |
| All page images | No | `/page/media-list/{title}` |
| Search | `action=query&list=search` | No |
| Multi-title batching | **Yes** — pipe-separate: `titles=A\|B\|C` (up to ~50) | No — one title per request |
| Combine multiple data types | **Yes** — `prop=revisions\|info\|pageprops` | No |
| Continuation tokens | **Yes** — `continue` object in response | No |
| Write operations | Yes (with auth) | No |
| Authentication required | No (read) | No |

### Batching multiple titles (api.php)

Pipe-separate titles in the `titles` param:
```
?action=query&titles=BTS%7CArirang_(album)%7CBlackpink&prop=pageprops&format=json
```

- `query.pages` is a map keyed by `pageid`
- `batchcomplete: ""` at the top level signals all data was returned
- `normalized[]` records any title rewrites (`Arirang_(album)` → `Arirang (album)`)
- Practical limit: ~50 titles per request

### Combining props in one api.php call

Pipe-separate `prop` values:
```
?action=query&prop=revisions|info|pageprops&rvprop=content&rvslots=main&ppprop=wikibase_item&titles=Arirang_(album)&format=json
```

Returns in a single response:
- from `info`: `pageid`, `ns`, `title`, `contentmodel`, `pagelanguage`, `touched`, `lastrevid`, `length`
- from `pageprops`: `wikibase_item` (Wikidata Q-ID)
- from `revisions`: `revisions[0].slots.main["*"]` (full wikitext)

For `action=parse`, combine with pipe too:
```
?action=parse&page={title}&prop=tocdata|text|revid|displaytitle&section=0&format=json
```
Returns lead section HTML + TOC + revision ID + display title in one call (~20 KB for section 0).

### Continuation (api.php)

When results are truncated (e.g., categories with `cllimit`), a `continue` object appears at the top level:

```json
{
  "continue": { "sroffset": 3, "continue": "-||" },
  "query": { ... }
}
```

To paginate: replay the original request and append all key-value pairs from the `continue` object as additional query params. Repeat until no `continue` key is present in the response.

### When to use each

| Use case | API choice |
|---|---|
| Display card (description, thumbnail, extract) | REST `/page/summary/` — one call, clean response |
| All page images / album cover | REST `/page/media-list/` — handles fair-use covers |
| Structured metadata (genre, release date, IDs) | Wikidata entity API |
| Section TOC + per-section content | `api.php` action=parse — no REST equivalent |
| Infobox field extraction | Wikidata first; wikitext via `api.php` as fallback |
| Search by name | `api.php` action=query&list=search |
| Fetch artist + album in one round-trip | `api.php` batched titles |
| Full article HTML (rare) | REST `/page/html/` — Parsoid HTML is cleaner than `prop=text` |

---

## 14. Language handling

### How Wikipedia's multilingual structure works

Each language edition is a **separate domain and separate database**. The English BTS page and the Korean 방탄소년단 page are distinct articles — different titles, different content, different revision history. They are linked only through Wikidata sitelinks.

```
en.wikipedia.org/wiki/BTS                    ←→  Q13580495  ←→  ko.wikipedia.org/wiki/방탄소년단
fr.wikipedia.org/wiki/BTS_(groupe)                              ja.wikipedia.org/wiki/BTS
```

All API endpoints are scoped to a language by subdomain: replace `en` with the target language code.

### Step 1 — Find the title in the target language

The **Wikidata sitelinks** map is the canonical source of truth for cross-language title lookup. From the `wikibase_item` Q-ID obtained in section 1:

```
GET https://www.wikidata.org/wiki/Special:EntityData/{Q-ID}.json
→ entities[Q].sitelinks.{lang}wiki.title
```

| `sitelinks` key | Language | BTS title |
|---|---|---|
| `enwiki` | English | `"BTS"` |
| `kowiki` | Korean | `"방탄소년단"` |
| `frwiki` | French | `"BTS (groupe)"` |
| `jawiki` | Japanese | `"BTS"` |
| `zhwiki` | Chinese | `"防彈少年團"` |
| `eswiki` | Spanish | `"BTS (banda)"` |
| `dewiki` | German | `"BTS (Band)"` |

A missing key means **no article exists in that language** — fall back to English.

### Step 2 — Fetch in target language

All REST and Action API endpoints accept the language subdomain:

```
GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}
GET https://{lang}.wikipedia.org/w/api.php?action=query&...&titles={title}&format=json
```

Example for French BTS summary:
```
GET https://fr.wikipedia.org/api/rest_v1/page/summary/BTS_(groupe)
```

Response `lang` field will be `"fr"`, `dir` will be `"ltr"`. Korean (`"ko"`) and Japanese (`"ja"`) are also `"ltr"`. Arabic (`"ar"`) and Hebrew (`"he"`) are `"rtl"`.

### Step 3 — Fallback strategy

Not all pages exist in all languages. Album pages are particularly sparse outside English and the artist's origin language (Korean for BTS). Recommended fallback chain:

```
1. Try target language (e.g., fr)
2. If sitelinks.{lang}wiki is absent in Wikidata → skip API call entirely
3. Fall back to English
4. Mark the response with the actual language used
```

Do not attempt a REST call if the sitelink is absent — the page simply does not exist, and the call will return 404.

### Language-specific data quality

| Language | Artist pages | Album pages | Notes |
|---|---|---|---|
| `en` | Best coverage, most detail | Good for major releases | Always available for notable artists |
| `ko` | Excellent for Korean artists | Good | Native language — often most detailed for K-pop |
| `ja` | Good for J-pop and K-pop | Moderate | Active music community |
| `fr` | Moderate | Poor | Album pages often stubs or absent |
| `zh` | Good for C-pop/K-pop | Sparse | Traditional and simplified variants differ |
| other | Varies widely | Usually absent | Check sitelinks before calling |

### Language detection fields

All REST summary responses include language metadata:

| Field | Path | Example |
|---|---|---|
| Language code | `lang` | `"en"`, `"ko"`, `"fr"` |
| Text direction | `dir` | `"ltr"` or `"rtl"` |
| Display title | `displaytitle` | May contain Unicode/RTL characters |

The Action API returns language metadata in `query.pages[id].pagelanguage` and `pagelanguagedir` when using `prop=info`.

### `prop=langlinks` — enumerate available languages

**Endpoint params:** `action=query&prop=langlinks&titles={title}&format=json&lllimit=500`

Returns all language editions that have an equivalent article:

```json
{
  "query": {
    "pages": {
      "39862325": {
        "langlinks": [
          { "lang": "ko", "url": "https://ko.wikipedia.org/wiki/...", "*": "방탄소년단" },
          { "lang": "fr", "url": "https://fr.wikipedia.org/wiki/...", "*": "BTS (groupe)" },
          ...
        ]
      }
    }
  }
}
```

| Field | Description |
|---|---|
| `lang` | Language code |
| `url` | Full URL to the equivalent page |
| `*` | Page title in that language |

BTS has ~90 language editions. Most album pages have 5–15.

**When to use `langlinks` vs Wikidata sitelinks:**
- `langlinks` is faster if you already have the English title and only need the target-language title (one API call, no Q-ID lookup).
- Wikidata sitelinks are better if you already fetched Wikidata for other properties — no extra call needed.

### Recommended implementation

```
fetch_in_language(title, lang):
  1. GET /api/rest_v1/page/summary/{title}       # English, get wikibase_item
  2. GET Wikidata/{Q-ID}.json                    # Get all sitelinks once
  3. localized_title = sitelinks[lang + "wiki"]  # nil if not present
  4. if localized_title:
       GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{localized_title}
     else:
       use English result, set language_used = "en"
```

Cache the Wikidata entity (sitelinks + properties) per Q-ID — it serves both language lookup and structured metadata (genre, release date, etc.) in a single fetch.
