export const OpenUrl = {
  mounted() {
    this.handleEvent("open_url", ({url}) => {
      window.open(url, '_blank')
    })
  }
};