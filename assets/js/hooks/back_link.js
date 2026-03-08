import { animate } from "motion"

export const BackLink = {
  mounted() {
    this.el.addEventListener("mouseenter", () => {
      animate(this.el, { scale: 1.08 }, { duration: 0.15, easing: "ease-out" })
    })

    this.el.addEventListener("mouseleave", () => {
      animate(this.el, { scale: 1 }, { duration: 0.15, easing: "ease-out" })
    })

    this.el.addEventListener("click", () => {
      animate(this.el, { x: [0, -60], opacity: [1, 0] }, { duration: 0.25, easing: "ease-in" })
    })
  }
}
