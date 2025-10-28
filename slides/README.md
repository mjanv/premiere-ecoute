# Premiere Ecoute Slides

This directory contains [Slidev](https://sli.dev/) presentations about Premiere Ecoute - an interactive music discovery platform for Twitch streamers and their communities.

## What is Slidev?

Slidev is a web-based slides maker and presenter for developers. It allows you to write presentations using Markdown with support for:
- Vue components and interactivity
- Syntax highlighting for code
- Live coding and demos
- PDF/PPTX export
- Presenter mode with notes

## Directory Structure

This setup supports multiple slide decks, each in its own subdirectory:

```
slides/
├── package.json           # Shared dependencies for all decks
├── scripts/
│   └── slidev-runner.js   # Dynamic deck runner script
├── premiere-ecoute/       # Main presentation deck
│   └── slides.md
└── [other-deck]/          # Add more decks here
    └── slides.md
```

Each subdirectory with a `slides.md` file is automatically discovered and can be run independently.

## Setup

### Prerequisites

- Node.js (v18 or later recommended)
- npm, yarn, or pnpm

### Installation

Navigate to the slides directory and install dependencies:

```bash
cd slides
npm install
```

## Usage

### List Available Decks

See all available slide decks:

```bash
npm run list
```

This will show all discovered decks in the slides directory.

### Development Mode

Start the development server with live reload:

```bash
# Run the first available deck (default)
npm run dev

# Run a specific deck by name
npm run dev premiere-ecoute
```

This will open the slides in your browser at `http://localhost:3030` (or another port if 3030 is occupied).

### Build for Production

Build the slides as a static website:

```bash
# Build the first available deck (default)
npm run build

# Build a specific deck
npm run build premiere-ecoute
```

The built files will be in the `dist/` directory and can be deployed to any static hosting service.

### Export to PDF

Export the slides to a PDF file:

```bash
# Export the first available deck (default)
npm run export

# Export a specific deck
npm run export premiere-ecoute

# Export with additional options
npm run export premiere-ecoute -- --format pdf --output my-presentation.pdf
```

This will generate a `slides-export.pdf` file in the current directory.

**Note**: PDF export requires Playwright Chromium. If you encounter issues during `npm install`, Playwright Chromium is marked as an optional dependency and won't prevent Slidev from working. To enable PDF export later, run:

```bash
npm run install:pdf-export
```

If this fails in your environment, you can use the built-in browser print-to-PDF feature as an alternative:
1. Run `npm run dev [deck-name]`
2. Open the presentation in your browser
3. Use your browser's print dialog (Ctrl/Cmd + P)
4. Select "Save as PDF"

### Export to PPTX

Export to PowerPoint format:

```bash
npm run export premiere-ecoute -- --format pptx
```

## Available Decks

### premiere-ecoute

The main presentation covering:

1. **Presentation** - Introduction to Premiere Ecoute
2. **Application Objectives** - Goals and principles
3. **Features** - Core functionality overview
   - Stream & Listen
   - Vote & React
   - Track & Rate
   - Overlays
4. **Technical Stack** - Architecture and technologies
5. **Deployment** - Production deployment on Fly.io
6. **Local Development** - Setup guide for contributors
7. **Roadmap** - Product and technical roadmap
8. **Funding** - Sustainability model and future plans
9. **Contributing** - How to get involved

## Creating New Decks

To create a new slide deck:

1. Create a new subdirectory in `slides/`:
   ```bash
   mkdir slides/my-new-deck
   ```

2. Create a `slides.md` file in that directory:
   ```bash
   touch slides/my-new-deck/slides.md
   ```

3. Add your Slidev content to `slides.md` (see the `premiere-ecoute` deck for examples)

4. The deck will be automatically discovered! Run:
   ```bash
   npm run list  # Verify it appears
   npm run dev my-new-deck  # Start developing
   ```

**Tip**: Copy the `premiere-ecoute` deck as a starting template:
```bash
cp -r slides/premiere-ecoute slides/my-new-deck
# Then edit slides/my-new-deck/slides.md
```

## Customization

### Editing Slides

Edit `slides.md` to modify the presentation content. Slidev uses standard Markdown with some extensions:

- Slides are separated by `---`
- Front matter at the top controls presentation settings
- Layout options control slide appearance
- `<v-clicks>` adds incremental reveals
- Full Vue component support

### Changing Theme

The presentation uses the default Slidev theme. To change it:

1. Install a different theme: `npm install @slidev/theme-seriph`
2. Update the `theme` property in the front matter of `slides.md`

Browse available themes at: https://sli.dev/themes/gallery

### Adding Assets

Place images, videos, or other assets in a `public/` directory within the slides folder. They can be referenced in slides using relative paths.

## Keyboard Shortcuts

When presenting:

- `Space` / `→` - Next slide
- `←` - Previous slide
- `f` - Toggle fullscreen
- `d` - Toggle dark mode
- `o` - Toggle overview mode
- `g` - Go to specific slide

## Tips for Presenting

1. Use presenter mode (click the icon in the navigation bar) to see notes and upcoming slides
2. Practice with the overview mode (`o`) to get familiar with the flow
3. Use `<v-clicks>` for complex slides to reveal content progressively
4. Test all transitions and animations before presenting

## Resources

- [Slidev Documentation](https://sli.dev/)
- [Slidev Themes Gallery](https://sli.dev/themes/gallery)
- [Markdown Syntax Guide](https://sli.dev/guide/syntax)
- [Vue Components in Slidev](https://sli.dev/custom/)

## Troubleshooting

### Port already in use

If port 3030 is occupied, Slidev will automatically use the next available port. Check the terminal output for the actual URL.

### PDF export fails

Ensure Playwright Chromium is installed:

```bash
npx playwright install chromium
```

### Dependencies issues

Remove `node_modules` and reinstall:

```bash
rm -rf node_modules
npm install
```

## AIDEV-NOTE: Slides maintenance
When updating features or roadmap in the main application, remember to update the corresponding slides in this presentation to keep it current.
