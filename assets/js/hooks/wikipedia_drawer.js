// AIDEV-NOTE: Bridges LiveView push_event → native DOM "drawer:open" event.
// The server sends "wiki-drawer:open:<drawer-id>" via push_event when the
// Wikipedia fetch succeeds. This hook dispatches the DOM event the Drawer
// hook is listening for.
export const WikipediaDrawer = {
  mounted() {
    const drawerId = this.el.dataset.drawerId

    this.handleEvent(`wiki-drawer:open:${drawerId}`, () => {
      const drawer = document.getElementById(drawerId)
      if (drawer) drawer.dispatchEvent(new Event("drawer:open", { bubbles: false }))
    })
  }
}
