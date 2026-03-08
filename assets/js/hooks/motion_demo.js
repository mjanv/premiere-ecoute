import { animate } from "motion"

export const MotionDemo = {
  mounted() {
    const cube = this.el.querySelector("[data-cube]")

    animate(
      cube,
      { y: [0, -80, 0] },
      { duration: 0.8, repeat: Infinity, easing: ["ease-in", "ease-out"] }
    )
  }
}
