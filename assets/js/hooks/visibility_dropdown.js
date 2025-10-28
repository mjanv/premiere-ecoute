export const VisibilityDropdown = {
  mounted() {
    this.button = this.el.querySelector('#visibility-dropdown-button');
    this.menu = this.el.querySelector('#visibility-dropdown-menu');
    this.chevron = this.el.querySelector('#dropdown-chevron');

    this.toggleDropdown = (e) => {
      e.stopPropagation(); // Prevent immediate triggering of closeDropdown
      const isHidden = this.menu.classList.contains('hidden');
      if (isHidden) {
        this.menu.classList.remove('hidden');
        this.chevron.style.transform = 'rotate(180deg)';
      } else {
        this.menu.classList.add('hidden');
        this.chevron.style.transform = 'rotate(0deg)';
      }
    };

    this.closeDropdown = (e) => {
      if (!this.el.contains(e.target)) {
        this.menu.classList.add('hidden');
        this.chevron.style.transform = 'rotate(0deg)';
      }
    };

    this.handleOptionClick = () => {
      // Close dropdown when an option is selected
      this.menu.classList.add('hidden');
      this.chevron.style.transform = 'rotate(0deg)';
    };

    this.button.addEventListener('click', this.toggleDropdown);
    document.addEventListener('click', this.closeDropdown);

    // Add click listener to all option buttons
    const optionButtons = this.menu.querySelectorAll('button[phx-click="update_visibility"]');
    optionButtons.forEach(btn => {
      btn.addEventListener('click', this.handleOptionClick);
    });
  },

  destroyed() {
    this.button.removeEventListener('click', this.toggleDropdown);
    document.removeEventListener('click', this.closeDropdown);

    // Clean up option button listeners
    const optionButtons = this.menu.querySelectorAll('button[phx-click="update_visibility"]');
    optionButtons.forEach(btn => {
      btn.removeEventListener('click', this.handleOptionClick);
    });
  }
};
