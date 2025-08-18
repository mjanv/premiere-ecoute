// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// AIDEV-NOTE: LiveView hooks for overlay functionality
const Hooks = {
  CopyToClipboard: {
    mounted() {
      this.handleEvent("copy_to_clipboard", ({text}) => {
        navigator.clipboard.writeText(text).then(() => {
          console.log("Text copied to clipboard:", text)
        }).catch(err => {
          console.error("Failed to copy text: ", err)
        })
      })
    }
  },

  OpenUrl: {
    mounted() {
      this.handleEvent("open_url", ({url}) => {
        window.open(url, '_blank')
      })
    }
  },

  // AIDEV-NOTE: Hook for GDPR data download functionality
  FileDownload: {
    mounted() {
      this.handleEvent("download_file", ({data, filename, content_type}) => {
        const blob = new Blob([data], { type: content_type })
        const url = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = url
        link.download = filename
        document.body.appendChild(link)
        link.click()
        window.URL.revokeObjectURL(url)
        document.body.removeChild(link)
      })
    }
  },

  // AIDEV-NOTE: Hook for localStorage persistence of playlist input
  PlaylistStorage: {
    mounted() {
      const storageKey = "billboard_playlist_input"
      
      // Always try to load from localStorage first
      const saved = localStorage.getItem(storageKey)
      if (saved) {
        this.el.value = saved
      }
      
      // Save value on input change
      this.el.addEventListener("input", (event) => {
        localStorage.setItem(storageKey, event.target.value)
      })
      
      // Handle loading state from server
      this.handleEvent("set_loading", ({loading}) => {
        this.el.disabled = loading
      })
    }
  },

  // AIDEV-NOTE: Hook for terminal-style rendering of ASCII art with glitch effects
  TerminalRender: {
    mounted() {
      this.asciiLines = [
        { text: "██████╗ ██╗██╗     ██╗     ██████╗  ██████╗  █████╗ ██████╗ ██████╗", color: "text-red-500" },
        { text: "██╔══██╗██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗", color: "text-orange-500" },
        { text: "██████╔╝██║██║     ██║     ██████╔╝██║   ██║███████║██████╔╝██║  ██║", color: "text-yellow-500" },
        { text: "██╔══██╗██║██║     ██║     ██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║", color: "text-green-500" },
        { text: "██████╔╝██║███████╗███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝", color: "text-blue-500" },
        { text: "╚═════╝ ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝", color: "text-purple-500" }
      ]
      this.initializeAsciiArt()
    },

    // AIDEV-NOTE: Handle LiveView updates that might clear the ASCII art
    updated() {
      // Check if the ASCII art content is missing and re-render if needed
      if (!this.el.innerHTML.trim() || !this.el.innerHTML.includes('██')) {
        this.initializeAsciiArt()
      }
    },

    initializeAsciiArt() {
      // Clear any existing timers to prevent conflicts
      this.clearTimers()
      this.startTerminalRender()
    },

    // AIDEV-NOTE: Clean up timers to prevent memory leaks and conflicts
    clearTimers() {
      if (this.renderTimer) {
        clearTimeout(this.renderTimer)
        this.renderTimer = null
      }
      if (this.glitchTimer) {
        clearTimeout(this.glitchTimer)
        this.glitchTimer = null
      }
    },

    destroyed() {
      this.clearTimers()
    },

    startTerminalRender() {
      this.el.innerHTML = ''
      
      // Initialize line states - all lines render simultaneously
      this.lineStates = this.asciiLines.map(line => ({
        text: line.text,
        color: line.color,
        currentIndex: 0,
        currentContent: '',
        isComplete: false
      }))
      
      this.renderAllLines()
    },

    renderAllLines() {
      const glitchChars = '█▓▒░▄▀▐▌▬▲▼◄►◦●○◉◎⦿⦾⌐¬½¼¡¿▪▫'
      let allComplete = true
      
      // Process each line independently
      this.lineStates.forEach((lineState, lineIndex) => {
        if (!lineState.isComplete) {
          allComplete = false
          const targetChar = lineState.text[lineState.currentIndex]
          
          if (targetChar) {
            // Sometimes show glitch characters before the real character
            if (Math.random() < 0.2 && targetChar !== ' ') {
              // Show glitch character briefly
              const glitchChar = glitchChars[Math.floor(Math.random() * glitchChars.length)]
              lineState.currentContent = lineState.text.substring(0, lineState.currentIndex) + glitchChar
              
              // Schedule the real character after glitch
              setTimeout(() => {
                lineState.currentContent = lineState.text.substring(0, lineState.currentIndex + 1)
                lineState.currentIndex++
                if (lineState.currentIndex >= lineState.text.length) {
                  lineState.isComplete = true
                }
              }, 50)
            } else {
              // Show character directly
              lineState.currentContent = lineState.text.substring(0, lineState.currentIndex + 1)
              lineState.currentIndex++
              if (lineState.currentIndex >= lineState.text.length) {
                lineState.isComplete = true
              }
            }
          }
        }
      })
      
      // Update display with all current line states
      this.updateDisplay()
      
      // Continue if not all lines are complete
      if (!allComplete) {
        this.renderTimer = setTimeout(() => this.renderAllLines(), Math.random() * 50 + 20) // Faster updates
      } else {
        // Start random glitches after completion
        this.startRandomGlitches()
      }
    },

    updateDisplay() {
      let content = ''
      
      this.lineStates.forEach((lineState, index) => {
        const startTag = `<span class="${lineState.color}">`
        const endTag = '</span>'
        content += startTag + lineState.currentContent + endTag
        
        // Add newline except for last line
        if (index < this.lineStates.length - 1) {
          content += '\n'
        }
      })
      
      this.el.innerHTML = content
    },

    startRandomGlitches() {
      const glitchChars = '█▓▒░▄▀▐▌▬▲▼◄►◦●○◉◎⦿⦾⌐¬½¼¡¿▪▫'
      
      const scheduleRandomGlitch = () => {
        // Random delay between glitches (2-8 seconds)
        const delay = Math.random() * 6000 + 2000
        
        this.glitchTimer = setTimeout(() => {
          // Choose type of glitch: 60% pixel, 25% vertical line, 15% horizontal line
          const glitchType = Math.random()
          if (glitchType < 0.6) {
            this.performPixelGlitch(glitchChars)
          } else if (glitchType < 0.85) {
            this.performVerticalLineGlitch(glitchChars)
          } else {
            this.performHorizontalLineGlitch(glitchChars)
          }
          scheduleRandomGlitch() // Schedule next glitch
        }, delay)
      }
      
      scheduleRandomGlitch()
    },

    performPixelGlitch(glitchChars) {
      // Pick a random line and position
      const lineIndex = Math.floor(Math.random() * this.asciiLines.length)
      const line = this.asciiLines[lineIndex]
      const charIndex = Math.floor(Math.random() * line.text.length)
      const originalChar = line.text[charIndex]
      
      // Skip spaces for glitching
      if (originalChar === ' ') return
      
      // Create glitched version
      const glitchChar = glitchChars[Math.floor(Math.random() * glitchChars.length)]
      const glitchedText = line.text.substring(0, charIndex) + glitchChar + line.text.substring(charIndex + 1)
      
      // Temporarily modify the line
      const originalText = line.text
      line.text = glitchedText
      
      // Update display with glitch
      let content = ''
      this.asciiLines.forEach((currentLine, index) => {
        const startTag = `<span class="${currentLine.color}">`
        const endTag = '</span>'
        content += startTag + currentLine.text + endTag
        
        if (index < this.asciiLines.length - 1) {
          content += '\n'
        }
      })
      this.el.innerHTML = content
      
      // Restore original after brief moment
      setTimeout(() => {
        line.text = originalText
        
        // Update display back to normal
        let restoredContent = ''
        this.asciiLines.forEach((currentLine, index) => {
          const startTag = `<span class="${currentLine.color}">`
          const endTag = '</span>'
          restoredContent += startTag + currentLine.text + endTag
          
          if (index < this.asciiLines.length - 1) {
            restoredContent += '\n'
          }
        })
        this.el.innerHTML = restoredContent
      }, Math.random() * 150 + 50) // Glitch duration: 50-200ms
    },

    performVerticalLineGlitch(glitchChars) {
      // Pick a random character position (vertical column)
      const charIndex = Math.floor(Math.random() * this.asciiLines[0].text.length)
      const originalChars = []
      const glitchedLines = []
      
      // Store original characters and create glitched versions
      this.asciiLines.forEach((line, index) => {
        originalChars[index] = line.text[charIndex]
        if (originalChars[index] && originalChars[index] !== ' ') {
          const glitchChar = glitchChars[Math.floor(Math.random() * glitchChars.length)]
          glitchedLines[index] = line.text.substring(0, charIndex) + glitchChar + line.text.substring(charIndex + 1)
        } else {
          glitchedLines[index] = line.text // Keep original if space or undefined
        }
      })
      
      // Apply glitch
      this.asciiLines.forEach((line, index) => {
        line.text = glitchedLines[index]
      })
      this.updateDisplay()
      
      // Restore after brief moment
      setTimeout(() => {
        this.asciiLines.forEach((line, index) => {
          line.text = line.text.substring(0, charIndex) + originalChars[index] + line.text.substring(charIndex + 1)
        })
        this.updateDisplay()
      }, Math.random() * 200 + 80) // Slightly longer for line glitches
    },

    performHorizontalLineGlitch(glitchChars) {
      // Pick a random line
      const lineIndex = Math.floor(Math.random() * this.asciiLines.length)
      const line = this.asciiLines[lineIndex]
      
      // Pick a random segment of the line (20-60% of the line)
      const segmentLength = Math.floor(line.text.length * (0.2 + Math.random() * 0.4))
      const startPos = Math.floor(Math.random() * (line.text.length - segmentLength))
      const endPos = startPos + segmentLength
      
      const originalText = line.text
      let glitchedText = line.text
      
      // Glitch the segment
      for (let i = startPos; i < endPos; i++) {
        if (originalText[i] && originalText[i] !== ' ') {
          const glitchChar = glitchChars[Math.floor(Math.random() * glitchChars.length)]
          glitchedText = glitchedText.substring(0, i) + glitchChar + glitchedText.substring(i + 1)
        }
      }
      
      // Apply glitch
      line.text = glitchedText
      this.updateDisplay()
      
      // Restore after brief moment
      setTimeout(() => {
        line.text = originalText
        this.updateDisplay()
      }, Math.random() * 250 + 100) // Longer duration for horizontal line glitches
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

