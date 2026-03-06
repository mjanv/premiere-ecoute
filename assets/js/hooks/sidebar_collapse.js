/**
 * Sidebar collapse hook - manages sidebar collapse/expand state with localStorage persistence
 * Handles toggle button clicks, state persistence, and CSS class application for transitions
 */
export const SidebarCollapse = {
  mounted() {
    this.restoreState();

    this.handleEvent("toggle-sidebar", () => {
      this.toggleSidebar();
    });

    const toggleBtn = this.el.querySelector('[data-sidebar-toggle]');
    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        this.toggleSidebar();
      });
    }
  },

  reconnected() {
    this.restoreState();
  },

  restoreState() {
    const savedState = localStorage.getItem('sidebar-collapsed');
    const isCollapsed = savedState === 'true';

    if (isCollapsed) {
      this.el.classList.add('sidebar-collapsed');
    } else {
      this.el.classList.remove('sidebar-collapsed');
    }
  },

  toggleSidebar() {
    const isCollapsed = this.el.classList.toggle('sidebar-collapsed');
    localStorage.setItem('sidebar-collapsed', isCollapsed.toString());
  }
};
