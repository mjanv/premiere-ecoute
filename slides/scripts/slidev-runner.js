#!/usr/bin/env node

/**
 * Slidev Runner - Dynamic deck management script
 *
 * This script automatically discovers and runs Slidev presentations
 * from subdirectories in the slides/ folder.
 *
 * Usage:
 *   node scripts/slidev-runner.js <command> [deck-name]
 *
 * Commands:
 *   dev      - Start development server
 *   build    - Build for production
 *   export   - Export to PDF/PPTX
 *   list     - List all available decks
 *
 * Examples:
 *   node scripts/slidev-runner.js dev premiere-ecoute
 *   node scripts/slidev-runner.js build
 *   node scripts/slidev-runner.js list
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// AIDEV-NOTE: Auto-discovery of slide decks by scanning subdirectories
const SLIDES_DIR = path.join(__dirname, '..');
const SLIDE_FILENAME = 'slides.md';

/**
 * Discover all available slide decks
 * @returns {Array<string>} Array of deck names
 */
function discoverDecks() {
  const entries = fs.readdirSync(SLIDES_DIR, { withFileTypes: true });

  return entries
    .filter(entry => entry.isDirectory() && entry.name !== 'node_modules' && entry.name !== 'scripts' && entry.name !== '.slidev')
    .filter(entry => {
      const slidePath = path.join(SLIDES_DIR, entry.name, SLIDE_FILENAME);
      return fs.existsSync(slidePath);
    })
    .map(entry => entry.name)
    .sort();
}

/**
 * List all available decks
 */
function listDecks() {
  const decks = discoverDecks();

  console.log('\n📊 Available slide decks:\n');

  if (decks.length === 0) {
    console.log('  No decks found. Create a subdirectory with a slides.md file.');
    console.log('  Example: slides/my-deck/slides.md\n');
    return;
  }

  decks.forEach((deck, index) => {
    const deckPath = path.join(SLIDES_DIR, deck, SLIDE_FILENAME);
    const stats = fs.statSync(deckPath);
    console.log(`  ${index + 1}. ${deck}`);
    console.log(`     Path: ${deck}/${SLIDE_FILENAME}`);
    console.log(`     Modified: ${stats.mtime.toLocaleDateString()}\n`);
  });
}

/**
 * Get the deck path to use
 * @param {string} deckName - Optional deck name
 * @returns {string|null} Deck path or null if not found
 */
function getDeckPath(deckName) {
  const decks = discoverDecks();

  if (decks.length === 0) {
    console.error('❌ No slide decks found.');
    console.error('   Create a subdirectory with a slides.md file.');
    console.error('   Example: slides/my-deck/slides.md\n');
    return null;
  }

  // If no deck specified, use the first one
  if (!deckName) {
    deckName = decks[0];
    console.log(`ℹ️  No deck specified, using: ${deckName}\n`);
  }

  // Check if the specified deck exists
  if (!decks.includes(deckName)) {
    console.error(`❌ Deck "${deckName}" not found.\n`);
    console.error('Available decks:');
    decks.forEach(deck => console.error(`  - ${deck}`));
    console.error('\nRun "npm run list" to see all available decks.\n');
    return null;
  }

  return path.join(deckName, SLIDE_FILENAME);
}

/**
 * Run Slidev command
 * @param {string} command - Slidev command (dev, build, export)
 * @param {string} deckPath - Path to the deck
 * @param {Array<string>} extraArgs - Additional arguments
 */
function runSlidev(command, deckPath, extraArgs = []) {
  const args = [command, deckPath, ...extraArgs];

  console.log(`🚀 Running: slidev ${args.join(' ')}\n`);

  const slidev = spawn('npx', ['slidev', ...args], {
    cwd: SLIDES_DIR,
    stdio: 'inherit',
    shell: true
  });

  slidev.on('error', (error) => {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
  });

  slidev.on('close', (code) => {
    if (code !== 0) {
      console.error(`\n❌ Slidev exited with code ${code}`);
      process.exit(code);
    }
  });
}

/**
 * Main entry point
 */
function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const deckName = args[1];
  const extraArgs = args.slice(2);

  // Show help if no command provided
  if (!command) {
    console.log('\n📊 Slidev Multi-Deck Runner\n');
    console.log('Usage: npm run <command> [deck-name] [-- extra-args]\n');
    console.log('Commands:');
    console.log('  dev      - Start development server');
    console.log('  build    - Build for production');
    console.log('  export   - Export to PDF/PPTX');
    console.log('  list     - List all available decks\n');
    console.log('Examples:');
    console.log('  npm run dev premiere-ecoute');
    console.log('  npm run build');
    console.log('  npm run export premiere-ecoute -- --format pptx');
    console.log('  npm run list\n');
    process.exit(0);
  }

  // Handle list command
  if (command === 'list') {
    listDecks();
    return;
  }

  // Validate command
  const validCommands = ['dev', 'build', 'export'];
  if (!validCommands.includes(command)) {
    console.error(`❌ Invalid command: ${command}`);
    console.error(`   Valid commands: ${validCommands.join(', ')}\n`);
    process.exit(1);
  }

  // Get deck path
  const deckPath = getDeckPath(deckName);
  if (!deckPath) {
    process.exit(1);
  }

  // Run Slidev
  runSlidev(command, deckPath, extraArgs);
}

// Run the script
main();
