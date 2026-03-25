import { animate } from "motion"

// AIDEV-NOTE: The hook owns ALL visibility state. Never call JS.show/JS.hide on
// the drawer or backdrop from Elixir — the inline style they set conflicts with
// classList.add("hidden") used here and breaks subsequent open/close cycles.
const OPEN_DURATION = 0.28
const CLOSE_DURATION = 0.22
const EASE_OPEN = [0.32, 0.72, 0, 1]   // ease-out-quart: snappy entry
const EASE_CLOSE = [0.4, 0, 0.6, 1]    // ease-in-quart: quick exit

export const Drawer = {
  mounted() {
    this.handleOpen = () => this._open()
    this.handleClose = () => this._close()
    this.closing = false

    this.el.addEventListener("drawer:open", this.handleOpen)
    this.el.addEventListener("drawer:close", this.handleClose)
  },

  destroyed() {
    this.el.removeEventListener("drawer:open", this.handleOpen)
    this.el.removeEventListener("drawer:close", this.handleClose)
  },

  _backdrop() {
    return document.getElementById(`${this.el.id}-backdrop`)
  },

  _open() {
    if (this.closing) return  // ignore open while close animation is running

    const backdrop = this._backdrop()

    // Make visible — remove hidden class AND clear any inline style left by
    // a previous JS.show call (defensive) or a stale transform from last close
    this.el.classList.remove("hidden")
    this.el.style.removeProperty("display")
    if (backdrop) {
      backdrop.classList.remove("hidden")
      backdrop.style.removeProperty("display")
    }

    document.body.classList.add("overflow-hidden")

    if (backdrop) {
      animate(backdrop, { opacity: [0, 1] }, { duration: OPEN_DURATION, easing: "ease-out" })
    }

    animate(
      this.el,
      { x: ["100%", "0%"] },
      { duration: OPEN_DURATION, easing: EASE_OPEN }
    )
  },

  _close() {
    if (this.closing) return
    this.closing = true

    const panel = this.el
    const backdrop = this._backdrop()

    if (backdrop) {
      animate(backdrop, { opacity: [1, 0] }, { duration: CLOSE_DURATION, easing: "ease-in" })
    }

    animate(
      panel,
      { x: ["0%", "100%"] },
      { duration: CLOSE_DURATION, easing: EASE_CLOSE }
    ).then(() => {
      panel.classList.add("hidden")
      if (backdrop) backdrop.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      this.closing = false
    })
  }
}
