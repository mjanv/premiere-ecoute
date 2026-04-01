import { createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { ExploreCanvas } from '../components/explorer/ExploreCanvas'

// AIDEV-NOTE: LiveView hook that mounts the React Flow canvas.
// explore.js registers this as window.__ExploreHooks.ExploreCanvas so it can be
// merged into the main LiveSocket hooks map in app.js without touching app.js
// more than necessary.
//
// Event protocol with LiveView (all push_event / handleEvent):
//   Server → Client:
//     "canvas:init"       { nodes, edges }   — first node, resets the canvas
//     "canvas:node_added" { node, edge }     — append a node + edge
//     "keeps:updated"     { keeps }          — sync keeps list
//   Client → Server:
//     "open_node"         { entity_type, entity_id, parent_id }
//     "keeps:add"         { entity_type, entity_id, label }
//     "keeps:remove"      { entity_type, entity_id }
//     "keeps:export"      { destination, items }

export const ExploreCanvasHook = {
  mounted() {
    // Callbacks registered by ExploreCanvas via onRegister().
    this._callbacks = null
    // Buffer events that arrive before React's useEffect has registered callbacks.
    this._pending = []

    const pushEvent = (event, payload) => this.pushEvent(event, payload)

    const onRegister = (callbacks) => {
      this._callbacks = callbacks
      // Flush buffered events in order.
      for (const buffered of this._pending) {
        this._dispatch(buffered)
      }
      this._pending = []
    }

    this._root = createRoot(this.el)
    this._root.render(
      createElement(ExploreCanvas, { onRegister, pushEvent })
    )

    // Listen for open_node events bubbling up from hotspot clicks inside cards.
    this._onOpenNode = (e) => {
      const { entityType, entityId, parentId } = e.detail
      this.pushEvent('open_node', {
        entity_type: entityType,
        entity_id: String(entityId),
        parent_id: parentId,
      })
    }
    this.el.addEventListener('explorer:open_node', this._onOpenNode)

    // Listen for keep events dispatched by node header Keep buttons.
    this._onKeep = (e) => {
      const { entity_type, entity_id, label } = e.detail
      this.pushEvent('keeps:add', { entity_type, entity_id, label })
    }
    this.el.addEventListener('explorer:keep', this._onKeep)

    // LiveView server → React state.
    this.handleEvent('canvas:init', (data) => this._enqueue({ type: 'init', data }))
    this.handleEvent('canvas:node_added', (data) => this._enqueue({ type: 'node_added', data }))
    this.handleEvent('keeps:updated', (data) => this._enqueue({ type: 'keeps_updated', data }))
  },

  destroyed() {
    this.el.removeEventListener('explorer:open_node', this._onOpenNode)
    this.el.removeEventListener('explorer:keep', this._onKeep)
    this._root?.unmount()
  },

  _enqueue(event) {
    if (this._callbacks) {
      this._dispatch(event)
    } else {
      this._pending.push(event)
    }
  },

  _dispatch({ type, data }) {
    switch (type) {
      case 'init':
        this._callbacks?.onInit?.(data)
        break
      case 'node_added':
        this._callbacks?.onNodeAdded?.(data)
        break
      case 'keeps_updated':
        this._callbacks?.setKeeps?.(data.keeps || [])
        break
    }
  },
}
