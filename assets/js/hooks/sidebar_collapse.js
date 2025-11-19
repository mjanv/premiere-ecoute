/**
 * AIDEV-NOTE: Sidebar collapse hook - manages sidebar collapse/expand state with localStorage persistence
 * Handles toggle button clicks, state persistence, and CSS class application for transitions
 */
export const SidebarCollapse = {
  mounted() {
    // AIDEV-NOTE: Initialize sidebar state from localStorage or default to expanded
    // Apply state immediately to prevent flash of wrong state
    this.restoreState();

    // AIDEV-NOTE: Listen for toggle button clicks
    this.handleEvent("toggle-sidebar", () => {
      this.toggleSidebar();
    });

    // AIDEV-NOTE: Add click handler for the toggle button
    const toggleBtn = this.el.querySelector('[data-sidebar-toggle]');
    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        this.toggleSidebar();
      });
    }
  },

  // AIDEV-NOTE: Restore state on reconnection after LiveView navigation
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
