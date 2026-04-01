/**
 * KeepsPanel
 *
 * In-session panel showing items the user has bookmarked during exploration.
 * State lives in LiveView assigns (server-side) and is synced here via push_event.
 *
 * Props:
 *   keeps        — array of { entity_type, entity_id, label }
 *   onClose()    — called when the panel is dismissed
 *   onRemove(item) — called to remove an item
 *   pushEvent    — hook's pushEvent for wantlist/pool export
 */
export function KeepsPanel({ keeps, onClose, onRemove, pushEvent }) {
  function handleExportWantlist() {
    pushEvent('keeps:export', { destination: 'wantlist', items: keeps })
  }

  function handleExportPool() {
    pushEvent('keeps:export', { destination: 'album_pool', items: keeps })
  }

  return (
    <div
      style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 320, zIndex: 20 }}
      className="bg-gray-900 border-l border-gray-800 flex flex-col shadow-2xl"
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-800">
        <h2 className="text-sm font-semibold text-white">
          Keeps{' '}
          <span className="ml-1 text-xs text-gray-400">({keeps.length})</span>
        </h2>
        <button
          onClick={onClose}
          className="text-gray-500 hover:text-gray-300 transition-colors"
          aria-label="Close keeps panel"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      {/* Items list */}
      <ul className="flex-1 overflow-y-auto divide-y divide-gray-800">
        {keeps.map((item) => (
          <li
            key={`${item.entity_type}-${item.entity_id}`}
            className="flex items-center gap-3 px-4 py-3"
          >
            <span className="flex-1 text-sm text-gray-200 truncate">{item.label}</span>
            <span className="text-xs text-gray-500 capitalize">{item.entity_type}</span>
            <button
              onClick={() => onRemove(item)}
              className="text-gray-600 hover:text-red-400 transition-colors flex-shrink-0"
              aria-label={`Remove ${item.label}`}
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </li>
        ))}
      </ul>

      {/* Export actions */}
      {keeps.length > 0 && (
        <div className="px-4 py-3 border-t border-gray-800 space-y-2">
          <button
            onClick={handleExportWantlist}
            className="w-full px-3 py-2 bg-purple-600 hover:bg-purple-700 rounded-lg text-sm font-medium text-white transition-colors"
          >
            Add to Wantlist
          </button>
          <button
            onClick={handleExportPool}
            className="w-full px-3 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg text-sm font-medium text-white transition-colors"
          >
            Add to Album Pool
          </button>
        </div>
      )}
    </div>
  )
}
