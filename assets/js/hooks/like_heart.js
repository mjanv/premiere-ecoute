import { animate } from "motion"

export const LikeHeart = {
  mounted() {
    this.el.closest("button").addEventListener("click", () => {
      animate(this.el, { rotate: [0, -30, 30, -20, 20, -10, 10, 0], scale: [1, 1.5, 1] }, { duration: 0.5 })
    })
  }
}
