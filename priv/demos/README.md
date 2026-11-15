# Demos

Standalone pages served in development at `/dev/demos/<name>` (index at `/dev/demos`). Add a `<name>.html` file here to add one.

## Reference videos

| Demo | Local URL | Reference video |
| --- | --- | --- |
| `liquid-type` | http://localhost:4000/dev/demos/liquid-type | https://pixlpin.com/media/designs/01M6KHFAD5DCN73RRMY6BERGT1/mp4-f6339848.mp4 |
| `vinyl-sleeve` | http://localhost:4000/dev/demos/vinyl-sleeve | None (built from a description) |
| `dot-card` | http://localhost:4000/dev/demos/dot-card | https://pixlpin.com/media/designs/01M4XA73X4W9DHAFSB1TC93FMQ/mp4-c18b9135.mp4 |
| `poster-flipbook` | http://localhost:4000/dev/demos/poster-flipbook | https://pixlpin.com/media/designs/01M4FX7HNA9VSK1H8ZJR5VW5PT/mp4-79c7f5bf.mp4 |
| `dither-cards` | http://localhost:4000/dev/demos/dither-cards | https://pixlpin.com/media/designs/01M4Y4TGFWKPRDFD5Y1AQNEJ59/mp4sm-96015784.mp4 |
| `image-decompose` | http://localhost:4000/dev/demos/image-decompose | https://pixlpin.com/media/designs/01M4FNMZMSXJZYM549CT50HS7G/mp4sm-fd107ae8.mp4 |
| `hover-stripes` | http://localhost:4000/dev/demos/hover-stripes | https://pixlpin.com/media/designs/01M6ECPJ9BEP4JBPQ07SXY44X4/mp4-4adbbb32.mp4 |
| `light-veils` | http://localhost:4000/dev/demos/light-veils | https://pixlpin.com/media/designs/01M4WYWV6MGPG3KTPFFKTAHW6P/mp4-03b013dc.mp4 |
| `heat-card` | http://localhost:4000/dev/demos/heat-card | https://pixlpin.com/media/designs/01M4FSRW5106925RM7P9QAEXMY/mp4sm-ac165a9f.mp4 |
| `stripe-stack` | http://localhost:4000/dev/demos/stripe-stack | https://pixlpin.com/media/designs/01M4ATD5QACJE1ME1D95GAZ93H/mp4sm-a8fdb927.mp4 |
| `squash-poster` | http://localhost:4000/dev/demos/squash-poster | https://pixlpin.com/media/designs/01M6BTDGPVQPCVH2FJA125QCYV/imagelg-85f26be3.webp (still image) |
| `block-type` | http://localhost:4000/dev/demos/block-type | https://pixlpin.com/media/designs/ (file `imagelg-2a8ce5e0.webp`, still image, full link not recorded) |
| `loud-type` | http://localhost:4000/dev/demos/loud-type | https://pixlpin.com/media/designs/01M623AJM8EF4CE8VYBJXDSJJM/mp4-d55e96c6.mp4 |
| `holo-disc` | http://localhost:4000/dev/demos/holo-disc | https://pixlpin.com/media/designs/01M4YCB5GEDN0VN4WENBR1SBYW/mp4-9d4a1ca6.mp4 |

## What each reference shows

- **liquid-type**: the word "NICE" turned 90°, each letter stretched to full width, filled with a flowing blue/magenta/red gradient, with a blur that swings along the word every 3 s.
- **dot-card**: a 2:3 card with a staggered dot grid, a jagged skyline of lit dots (white crest, cyan, blue, purple) and beams of light rising above it.
- **poster-flipbook**: seven posters for one event, each held about 0.4 s with hard cuts. The demo keeps the format and uses Wrapped content; the reference's branding and slogans are not copied.
- **dither-cards**: two rounded cards on light grey. The left one shows flowing orange ribbons rendered as square halftone dots, above a serif heading. The right one has a pale blue heading block over a blue block with a column of dithered, morphing shapes. The demo uses its own text and mark.
- **image-decompose**: a poster series built on one black and white portrait, taken apart in different ways (shifted strips, tiles, pixel blocks) with blue elements laid over it. The demo keeps only the decomposition idea, as four modes on one picture, not the series of posters or the portrait.
- **hover-stripes**: two cards, each a text block plus a panel of ten thin vertical lines (dark on lilac, lilac on dark). Where the pointer hovers, the lines swell into wide tapered spindles.
- **holo-disc**: a disc of small square dots on black, lit by slow holographic bands (dark red, violet, blue, teal) with thin bright streaks, fading into scattered dots where it is dim.
- **light-veils**: a full-frame background of soft lavender and pink ribbons of light folding slowly over dark plum, slightly blurred, with a fine printed grain.
- **heat-card**: a tall rounded card on light grey filled with heavily blurred, slightly blocky footage recoloured in neon green, pink, orange and navy, with a glowing rim and a white mark and word across the middle. The demo draws its own moving picture (or blurs an uploaded one) and uses its own mark and word.
- **stripe-stack**: heavy words on black, extruded in depth as a stack of thin coloured stripes that fan out in perspective, with the colour shifting from front to back (pink to red, lime to cyan, orange to violet). The view drifts slowly and cuts between angles. The demo uses its own words, not the reference's event text.
- **squash-poster**: an event poster built from one three-part mark repeated at several vertical scales (full height in a flat blue band, squashed to thin strips above), a three-column grid with one word per column, a smeared green and violet gradient with a jagged edge, a stepped pixel frame, an orange information block and small print as edging. The demo reuses those layout ideas with its own words and date. Its three marks are redrawn after the poster's (the event's own logo shapes), so this card is a study, not something to ship.
- **block-type**: one tall condensed word repeated like bricks across a red square, each letter a solid block with a cream face and a pink top, the walls the same red as the background. The demo uses its own word and adds slow motion.
- **loud-type**: three stacked words in condensed heavy type on black, drawn at 12 frames per second like stop motion. They start tiny, grow in jumps with colours swapping and hand-drawn white marks, fill the screen, invert into full-width colour bands with dark words sliding sideways, then collapse.

## URL parameters

| Demo | Parameters |
| --- | --- |
| `liquid-type` | `text`, `layout=lines`, `palette=Neon\|Acid\|Ember\|Ice`, `time=<seconds>` |
| `vinyl-sleeve` | `yaw`, `pitch`, `pull=1`, `artist`, `album` |
| `dot-card` | `palette=Ice\|Ember\|Acid`, `time=<seconds>` |
| `poster-flipbook` | `poster=0..6` |
| `dither-cards` | `time=<seconds>` |
| `image-decompose` | `mode=Slices\|Squares\|Tiles\|Mosaic`, `amount=0..1` |
| `hover-stripes` | `palette=Lilac\|Lime\|Coral`, `x`, `y`, `strength` (0..1, freezes the focus point) |
| `holo-disc` | `time=<seconds>` |
| `light-veils` | `palette=Plum\|Sea\|Ember`, `time=<seconds>` |
| `heat-card` | `palette=Neon\|Deep\|Dusk`, `time=<seconds>`, `text` |
| `stripe-stack` | `text`, `scene=0..3`, `at=0..1` (freezes a scene at that point) |
| `squash-poster` | `time=<seconds>` |
| `block-type` | `text` (up to 8 letters), `palette=Red\|Night\|Lime`, `time=<seconds>` |
| `loud-type` | `text` (up to three words), `frame=0..63`, `clean` (skips the dirty photocopy pass) |
