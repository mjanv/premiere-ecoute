import { animate } from "motion"

// AIDEV-NOTE: AnalyticsChart renders a bar chart from JSON data passed via
// data-inline-data. Uses Motion.js for entrance animations and hover
// micro-interactions. Grouped series render a DOM legend above the SVG.

const SERIES_COLORS = [
  "#a78bfa", // violet-400
  "#34d399", // emerald-400
  "#fb923c", // orange-400
  "#38bdf8", // sky-400
  "#f472b6", // pink-400
  "#facc15", // yellow-400
]

function formatLabel(dateStr, unit) {
  const d = new Date(dateStr)
  if (unit === "month") return d.toLocaleDateString("en", { month: "short", year: "2-digit" })
  if (unit === "week") return d.toLocaleDateString("en", { month: "short", day: "numeric" })
  if (unit === "day") return d.toLocaleDateString("en", { month: "short", day: "numeric" })
  if (unit === "year") return String(d.getFullYear())
  return dateStr
}

function hexToRgb(hex) {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return [r, g, b]
}

function buildLegend(container, seriesKeys) {
  const legend = document.createElement("div")
  legend.style.cssText = "display:flex;flex-wrap:wrap;gap:8px;margin-bottom:10px;"
  seriesKeys.forEach((key, i) => {
    const color = SERIES_COLORS[i % SERIES_COLORS.length]
    const [r, g, b] = hexToRgb(color)
const pill = document.createElement("span")
    pill.style.display = "inline-block"
    pill.style.padding = "2px 8px"
    pill.style.borderRadius = "4px"
    pill.style.fontSize = "12px"
    pill.style.fontWeight = "600"
    pill.style.background = `rgba(${r},${g},${b},0.15)`
    pill.style.color = color
    pill.style.border = `1px solid rgba(${r},${g},${b},0.4)`
    pill.style.letterSpacing = "0.02em"
    pill.textContent = key
    legend.appendChild(pill)
  })
  container.appendChild(legend)
  return legend
}

function buildBarChart(wrapper, data, unit) {
  wrapper.innerHTML = ""

  if (!data || data.length === 0) {
    wrapper.innerHTML = `<div style="display:flex;align-items:center;justify-content:center;height:100%;color:#6b7280;font-size:14px;">No data for this period</div>`
    return
  }

  const isGrouped = data.some(d => d.series)
  let periods, seriesKeys, seriesData

  if (isGrouped) {
    const periodMap = {}
    data.forEach(d => {
      if (!periodMap[d.period]) periodMap[d.period] = {}
      periodMap[d.period][d.series] = (periodMap[d.period][d.series] || 0) + d.count
    })
    periods = Object.keys(periodMap).sort()
    seriesKeys = [...new Set(data.map(d => d.series))].sort()
    seriesData = periods.map(p => {
      const entry = { period: p }
      seriesKeys.forEach(s => { entry[s] = periodMap[p][s] || 0 })
      return entry
    })
  } else {
    periods = data.map(d => d.period)
    seriesKeys = ["count"]
    seriesData = data.map(d => ({ period: d.period, count: d.count }))
  }

  // DOM legend for grouped charts
  if (isGrouped) {
    buildLegend(wrapper, seriesKeys)
  }

  // SVG container
  const svgWrap = document.createElement("div")
  svgWrap.style.cssText = "flex:1;min-height:0;"
  wrapper.appendChild(svgWrap)

  const chartWidth = svgWrap.clientWidth || wrapper.clientWidth || 400
  const legendH = isGrouped ? 28 : 0
  const totalH = wrapper.clientHeight || 176
  const chartHeight = totalH - legendH

  const padLeft = 32
  const padBottom = 28
  const padTop = 8
  const padRight = 6
  const innerH = chartHeight - padBottom - padTop
  const innerW = chartWidth - padLeft - padRight

  const maxVal = Math.max(...seriesData.flatMap(d => seriesKeys.map(s => d[s] || 0)), 1)
  const barGroupW = innerW / periods.length
  const barPad = Math.max(1, barGroupW * 0.15)
  const groupGap = isGrouped ? 2 : 0
  const barW = Math.max(2, (barGroupW - barPad * 2 - groupGap * (seriesKeys.length - 1)) / seriesKeys.length)

  const svgNS = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(svgNS, "svg")
  svg.setAttribute("width", chartWidth)
  svg.setAttribute("height", chartHeight)
  svg.style.display = "block"

  // Grid lines + Y labels
  const gridCount = 3
  for (let i = 0; i <= gridCount; i++) {
    const y = padTop + innerH - (i / gridCount) * innerH
    const line = document.createElementNS(svgNS, "line")
    line.setAttribute("x1", padLeft)
    line.setAttribute("x2", padLeft + innerW)
    line.setAttribute("y1", y)
    line.setAttribute("y2", y)
    line.setAttribute("stroke", i === 0 ? "#374151" : "#1f2937")
    line.setAttribute("stroke-width", "1")
    svg.appendChild(line)

    if (i > 0) {
      const t = document.createElementNS(svgNS, "text")
      t.setAttribute("x", padLeft - 5)
      t.setAttribute("y", y + 4)
      t.setAttribute("text-anchor", "end")
      t.setAttribute("fill", "#d1d5db")
      t.setAttribute("font-size", "11")
      t.textContent = Math.round((i / gridCount) * maxVal)
      svg.appendChild(t)
    }
  }

  // Bars
  const barEls = []
  seriesData.forEach((entry, i) => {
    const groupX = padLeft + i * barGroupW + barPad

    seriesKeys.forEach((key, si) => {
      const val = entry[key] || 0
      const barH = Math.max(2, (val / maxVal) * innerH)
      const x = groupX + si * (barW + groupGap)
      const baseY = padTop + innerH
      const color = SERIES_COLORS[si % SERIES_COLORS.length]

      const rect = document.createElementNS(svgNS, "rect")
      rect.setAttribute("x", x)
      rect.setAttribute("y", baseY)
      rect.setAttribute("width", barW)
      rect.setAttribute("height", 0)
      rect.setAttribute("rx", "2")
      rect.setAttribute("fill", color)
      rect.setAttribute("opacity", "0.8")
      rect.dataset.targetY = baseY - barH
      rect.dataset.targetH = barH
      rect.dataset.val = val
      rect.dataset.label = `${formatLabel(entry.period, unit)}${isGrouped ? ` · ${key}` : ""}: ${val}`
      svg.appendChild(rect)
      barEls.push(rect)
    })

    // X axis label — thin out when many periods
    const skip = periods.length > 18 ? Math.ceil(periods.length / 12) : 1
    if (i % skip === 0) {
      const t = document.createElementNS(svgNS, "text")
      t.setAttribute("x", padLeft + i * barGroupW + barGroupW / 2)
      t.setAttribute("y", chartHeight - 4)
      t.setAttribute("text-anchor", "middle")
      t.setAttribute("fill", "#d1d5db")
      t.setAttribute("font-size", "11")
      t.textContent = formatLabel(entry.period, unit)
      svg.appendChild(t)
    }
  })

  svgWrap.appendChild(svg)

  // Animate bars rising from baseline
  barEls.forEach((rect, i) => {
    const targetY = parseFloat(rect.dataset.targetY)
    const targetH = parseFloat(rect.dataset.targetH)
    const baseY = padTop + innerH
    animate(
      rect,
      { y: [0, targetY - baseY], height: [0, targetH] },
      { duration: 0.45, delay: i * 0.015, easing: [0.22, 1, 0.36, 1] }
    )
  })

  // Tooltip on hover
  const tooltip = document.createElement("div")
  tooltip.style.cssText = "position:fixed;background:#1f2937;border:1px solid #374151;color:#f9fafb;font-size:12px;padding:5px 10px;border-radius:4px;pointer-events:none;opacity:0;transition:opacity 0.1s;white-space:nowrap;z-index:100;"
  document.body.appendChild(tooltip)

  barEls.forEach(rect => {
    rect.style.cursor = "default"
    rect.addEventListener("mouseenter", e => {
      animate(rect, { opacity: 1 }, { duration: 0.1 })
      tooltip.textContent = rect.dataset.label
      tooltip.style.opacity = "1"
    })
    rect.addEventListener("mousemove", e => {
      tooltip.style.left = (e.clientX + 12) + "px"
      tooltip.style.top = (e.clientY - 28) + "px"
    })
    rect.addEventListener("mouseleave", () => {
      animate(rect, { opacity: 0.8 }, { duration: 0.1 })
      tooltip.style.opacity = "0"
    })
  })

  // Clean up tooltip when hook is destroyed
  wrapper._tooltipEl = tooltip
}

function buildSparkline(container, data) {
  if (!data || data.length < 2) {
    container.innerHTML = ""
    return
  }

  const w = container.clientWidth || 120
  const h = container.clientHeight || 32
  const maxVal = Math.max(...data.map(d => d.count), 1)
  const step = w / (data.length - 1)

  const points = data.map((d, i) => {
    const x = i * step
    const y = h - (d.count / maxVal) * h * 0.9
    return [x, y]
  })

  const svgNS = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(svgNS, "svg")
  svg.setAttribute("width", "100%")
  svg.setAttribute("height", "100%")
  svg.setAttribute("viewBox", `0 0 ${w} ${h}`)
  svg.style.overflow = "visible"

  // Fill area
  const fillPts = [...points, [w, h], [0, h]].map(p => p.join(",")).join(" ")
  const poly = document.createElementNS(svgNS, "polygon")
  poly.setAttribute("points", fillPts)
  poly.setAttribute("fill", "rgba(167,139,250,0.15)")
  svg.appendChild(poly)

  // Line
  const pathD = points.map((p, i) => `${i === 0 ? "M" : "L"}${p[0]},${p[1]}`).join(" ")
  const path = document.createElementNS(svgNS, "path")
  path.setAttribute("d", pathD)
  path.setAttribute("stroke", "#a78bfa")
  path.setAttribute("stroke-width", "1.5")
  path.setAttribute("fill", "none")
  path.setAttribute("stroke-linecap", "round")
  path.setAttribute("stroke-linejoin", "round")

  const totalLen = path.getTotalLength?.() || 300
  path.style.strokeDasharray = totalLen
  path.style.strokeDashoffset = totalLen
  svg.appendChild(path)

  container.innerHTML = ""
  container.appendChild(svg)

  animate(path, { strokeDashoffset: [totalLen, 0] }, { duration: 0.8, easing: "ease-out" })
}

export const AnalyticsChart = {
  mounted() {
    this.unit = this.el.dataset.unit || "month"
    this.chartId = this.el.dataset.chartId

    this.handleEvent(`analytics:${this.chartId}:data`, ({ data }) => {
      this.render(data)
    })

    const inline = this.el.dataset.inlineData
    if (inline) {
      try { this.render(JSON.parse(inline)) } catch (_) {}
    }
  },

  updated() {
    this.unit = this.el.dataset.unit || "month"
    const inline = this.el.dataset.inlineData
    if (inline) {
      try { this.render(JSON.parse(inline)) } catch (_) {}
    }
  },

  destroyed() {
    if (this.el._tooltipEl) this.el._tooltipEl.remove()
  },

  render(data) {
    if (this.el._tooltipEl) this.el._tooltipEl.remove()
    buildBarChart(this.el, data, this.unit)
  }
}
