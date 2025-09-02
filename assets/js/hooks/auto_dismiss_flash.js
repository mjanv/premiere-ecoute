export const AutoDismissFlash = {
  mounted() {
    setTimeout(() => {
      this.el.style.transition = "opacity 0.5s";
      this.el.style.opacity = "0";
      setTimeout(() => this.el.remove(), 500);
    }, 10000);
  },
};
