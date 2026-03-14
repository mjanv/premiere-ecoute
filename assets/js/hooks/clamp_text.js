// AIDEV-NOTE: hides the "more" button when text fits within the clamped height; must run after layout
export const ClampText = {
  mounted() {
    requestAnimationFrame(() => {
      const p = this.el.querySelector("p")
      const btn = this.el.querySelector("button")
      if (p && btn && p.scrollHeight <= p.clientHeight) {
        btn.style.display = "none"
      }
    })
  }
}
