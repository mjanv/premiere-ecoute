import { Handle, Position } from '@xyflow/react'

/**
 * TrackNode
 *
 * Renders an embedded Spotify or Deezer player for a track.
 * data prop shape: { id, label, entity_id, provider_ids: { spotify?, deezer? } }
 */
export function TrackNode({ data }) {
  const spotifyId = data.provider_ids?.spotify
  const deezerId = data.provider_ids?.deezer

  return (
    <div
      style={{ width: 440 }}
      className="bg-gray-800 border border-gray-700 rounded-xl shadow-2xl overflow-hidden"
    >
      {/* Node header */}
      <div className="flex items-center gap-3 p-4 border-b border-gray-700 bg-gray-900">
        <div className="w-8 h-8 rounded-full bg-purple-600 flex items-center justify-center flex-shrink-0">
          <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 24 24">
            <path d="M8 5v14l11-7z" />
          </svg>
        </div>
        <div className="min-w-0">
          <h3 className="font-semibold text-white truncate text-sm">{data.label}</h3>
          {data.subtitle && (
            <p className="text-xs text-gray-400 mt-0.5 truncate">{data.subtitle}</p>
          )}
        </div>
      </div>

      {/* Embedded player */}
      <div className="p-2">
        {spotifyId ? (
          <iframe
            title={`Spotify player — ${data.label}`}
            src={`https://open.spotify.com/embed/track/${spotifyId}?utm_source=generator&theme=0`}
            width="100%"
            height="152"
            frameBorder="0"
            allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
            loading="lazy"
            className="rounded-lg"
          />
        ) : deezerId ? (
          <iframe
            title={`Deezer player — ${data.label}`}
            src={`https://widget.deezer.com/widget/dark/track/${deezerId}`}
            width="100%"
            height="152"
            frameBorder="0"
            allow="autoplay; clipboard-write; encrypted-media"
            loading="lazy"
            className="rounded-lg"
          />
        ) : (
          <div className="h-24 flex items-center justify-center text-sm text-gray-500">
            No embedded player available
          </div>
        )}
      </div>

      <Handle type="target" position={Position.Left} className="!bg-purple-500" />
      <Handle type="source" position={Position.Right} className="!bg-purple-500" />
    </div>
  )
}
