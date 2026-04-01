import { useCallback, useEffect, useRef, useState } from 'react'
import {
  ReactFlow,
  Background,
  Controls,
  useNodesState,
  useEdgesState,
  addEdge,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import dagre from '@dagrejs/dagre'
import { ArtistNode } from './nodes/ArtistNode'
import { TrackNode } from './nodes/TrackNode'
import { KeepsPanel } from './KeepsPanel'

const NODE_TYPES = {
  artist: ArtistNode,
  album: ArtistNode,  // albums use the same card-stack layout as artists
  track: TrackNode,
}

// AIDEV-NOTE: fixed dimensions used by dagre for layout; must match node CSS dimensions.
const NODE_WIDTH = 440
const NODE_HEIGHT = 580

function applyDagreLayout(nodes, edges) {
  const g = new dagre.graphlib.Graph()
  g.setDefaultEdgeLabel(() => ({}))
  g.setGraph({ rankdir: 'LR', nodesep: 80, ranksep: 100 })

  nodes.forEach((node) => {
    g.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT })
  })

  edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target)
  })

  dagre.layout(g)

  return nodes.map((node) => {
    const { x, y } = g.node(node.id)
    return {
      ...node,
      position: { x: x - NODE_WIDTH / 2, y: y - NODE_HEIGHT / 2 },
    }
  })
}

function toRfNode(raw) {
  return {
    id: raw.id,
    type: raw.entity_type,
    position: { x: 0, y: 0 },
    data: raw,
  }
}

function toRfEdge(raw) {
  return {
    id: raw.id,
    source: raw.source,
    target: raw.target,
    animated: true,
    style: { stroke: '#7c3aed' },
  }
}

/**
 * ExploreCanvas
 *
 * Props:
 *   onRegister(callbacks) — called once after mount; the hook stores callbacks
 *                           so it can push LiveView events into React state.
 *   pushEvent(event, payload) — calls this.pushEvent on the LiveView hook.
 */
export function ExploreCanvas({ onRegister, pushEvent }) {
  const [nodes, setNodes, onNodesChange] = useNodesState([])
  const [edges, setEdges, onEdgesChange] = useEdgesState([])
  const [keeps, setKeeps] = useState([])
  const [showKeeps, setShowKeeps] = useState(false)

  // Track current graph outside React render cycle for layout recomputation.
  // AIDEV-NOTE: graphRef avoids stale-closure issues in async callbacks.
  const graphRef = useRef({ nodes: [], edges: [] })

  const onInit = useCallback(({ nodes: rawNodes, edges: rawEdges }) => {
    const rfNodes = rawNodes.map(toRfNode)
    const rfEdges = rawEdges.map(toRfEdge)
    const laidNodes = applyDagreLayout(rfNodes, rfEdges)
    graphRef.current = { nodes: laidNodes, edges: rfEdges }
    setNodes(laidNodes)
    setEdges(rfEdges)
  }, [])

  const onNodeAdded = useCallback(({ node: rawNode, edge: rawEdge }) => {
    const rfNode = toRfNode(rawNode)
    const rfEdge = rawEdge ? toRfEdge(rawEdge) : null

    const allNodes = [...graphRef.current.nodes, rfNode]
    const allEdges = rfEdge ? [...graphRef.current.edges, rfEdge] : graphRef.current.edges

    const laidNodes = applyDagreLayout(allNodes, allEdges)
    graphRef.current = { nodes: laidNodes, edges: allEdges }

    setNodes(laidNodes)
    if (rfEdge) setEdges(allEdges)
  }, [])

  // Register callbacks with the LiveView hook so it can drive state.
  useEffect(() => {
    onRegister({ onInit, onNodeAdded, setKeeps })
  }, [onRegister, onInit, onNodeAdded])

  const handleNodeClick = useCallback(
    (entityType, entityId, parentNodeId) => {
      pushEvent('open_node', {
        entity_type: entityType,
        entity_id: String(entityId),
        parent_id: parentNodeId,
      })
    },
    [pushEvent]
  )

  const handleKeepsAdd = useCallback(
    (item) => {
      pushEvent('keeps:add', item)
    },
    [pushEvent]
  )

  const handleKeepsRemove = useCallback(
    (item) => {
      pushEvent('keeps:remove', item)
    },
    [pushEvent]
  )

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={NODE_TYPES}
        nodesDraggable={false}
        fitView
        fitViewOptions={{ padding: 0.2 }}
        nodeOrigin={[0, 0]}
        proOptions={{ hideAttribution: true }}
      >
        <Background color="#374151" gap={24} size={1} />
        <Controls showInteractive={false} />
      </ReactFlow>

      {/* Keeps panel — slides in from the right */}
      {showKeeps && (
        <KeepsPanel
          keeps={keeps}
          onClose={() => setShowKeeps(false)}
          onRemove={handleKeepsRemove}
          pushEvent={pushEvent}
        />
      )}

      {/* Keeps toggle button — rendered inside the canvas overlay */}
      {keeps.length > 0 && (
        <button
          onClick={() => setShowKeeps((v) => !v)}
          style={{
            position: 'absolute',
            top: 12,
            right: 12,
            zIndex: 10,
          }}
          className="flex items-center gap-2 px-3 py-2 bg-gray-800 hover:bg-gray-700 border border-gray-700 rounded-lg text-sm font-medium text-white transition-colors"
        >
          Keeps
          <span className="inline-flex items-center justify-center w-5 h-5 text-xs bg-purple-600 rounded-full">
            {keeps.length}
          </span>
        </button>
      )}
    </div>
  )
}
