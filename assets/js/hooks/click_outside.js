export const ClickOutside = {
  mounted() {
    this.handleClickOutside = (e) => {
      if (!this.el.contains(e.target)) {
        const event = this.el.dataset.event;
        if (event) {
          this.pushEvent(event, {});
        }
      }
    };
    
    document.addEventListener('click', this.handleClickOutside);
  },
  
  destroyed() {
    document.removeEventListener('click', this.handleClickOutside);
  }
};