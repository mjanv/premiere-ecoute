// AIDEV-NOTE: separate esbuild entry point for the /explore page.
// Bundles React + React Flow + dagre WITHOUT including them in app.js.
// Must load (via <script defer>) BEFORE app.js so that window.__ExploreHooks
// is populated before LiveSocket is initialized.

import { ExploreCanvasHook } from './hooks/explore_canvas'

window.__ExploreHooks = {
  ExploreCanvas: ExploreCanvasHook,
}
