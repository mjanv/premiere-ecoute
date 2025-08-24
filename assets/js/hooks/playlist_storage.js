
export const PlaylistStorage = {
    mounted() {
      const storageKey = "billboard_playlist_input"

      const saved = localStorage.getItem(storageKey)
      if (saved) {
        this.el.value = saved
      }

      this.el.addEventListener("input", (event) => {
        localStorage.setItem(storageKey, event.target.value)
      })

      this.handleEvent("set_loading", ({loading}) => {
        this.el.disabled = loading
      })
    }
  }