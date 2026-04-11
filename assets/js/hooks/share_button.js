export const ShareButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      const url = this.el.dataset.url;

      const confirm = () => {
        this.el.title = "Copied!";
        this.el.classList.add("text-purple-300");
        this.el.style.borderColor = "rgb(216 180 254)"; // purple-300
        setTimeout(() => {
          this.el.title = "Copy link";
          this.el.classList.remove("text-purple-300");
          this.el.style.borderColor = "";
        }, 2000);
      };

      if (navigator.share) {
        navigator.share({ url }).catch(() => {});
      } else {
        navigator.clipboard.writeText(url).then(confirm).catch(() => {});
      }
    });
  }
};
