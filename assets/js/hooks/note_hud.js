export const NoteHud = {
  mounted() {
    this.handleKeydown = (e) => {
      if (e.key === "Tab" && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
        e.preventDefault();
        const input = document.getElementById("note-hud-input");
        if (input) {
          this.pushEvent("close_note_hud", {});
        } else {
          this.pushEvent("toggle_note_hud", {});
        }
      }

      if (e.key === "Escape") {
        this.pushEvent("close_note_hud", {});
      }

      if (e.key === "Enter") {
        const input = document.getElementById("note-hud-input");
        if (!input) return;

        if (e.altKey) {
          // Alt+Enter: insert newline and grow
          e.preventDefault();
          const pos = input.selectionStart;
          input.value = input.value.slice(0, pos) + "\n" + input.value.slice(pos);
          input.selectionStart = input.selectionEnd = pos + 1;
          autoResize(input);
        } else if (!e.shiftKey && !e.ctrlKey && !e.metaKey) {
          // Plain Enter: submit the form
          e.preventDefault();
          input.closest("form").requestSubmit();
        }
      }
    };

    document.addEventListener("keydown", this.handleKeydown);

    this.handleInput = (e) => {
      if (e.target.id === "note-hud-input") autoResize(e.target);
    };
    document.addEventListener("input", this.handleInput);

    this.handleEvent("clear_note_input", () => {
      const input = document.getElementById("note-hud-input");
      if (!input) return;
      input.value = "";
      autoResize(input);
      input.focus();
    });
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeydown);
    document.removeEventListener("input", this.handleInput);
  },
};

function autoResize(el) {
  el.style.height = "auto";
  el.style.height = el.scrollHeight + "px";
}
