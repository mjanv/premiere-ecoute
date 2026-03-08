import { animate } from "motion"

export const BarBounce = {
  mounted() {
    this.el.querySelectorAll("[data-bar]").forEach(bar => {
      bar.addEventListener("mouseenter", () => {
        animate(bar, { scaleY: [1, 1.12, 0.95, 1] }, { duration: 0.35, easing: "ease-out" })
      })
    })
  }
}
