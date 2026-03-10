export const ScrollToActive = {
  mounted() { this.scrollToActive() },
  updated() { this.scrollToActive() },
  scrollToActive() {
    const active = this.el.querySelector("[data-active]")
    if (active) active.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }
}
