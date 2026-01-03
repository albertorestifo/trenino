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
import {hooks as colocatedHooks} from "phoenix-colocated/tsw_io"
import topbar from "../vendor/topbar"

// Normalize key codes to human-readable format for keystroke capture
function normalizeKey(code) {
  // Single letter keys
  if (code.startsWith("Key")) {
    return code.slice(3) // "KeyW" -> "W"
  }
  // Digit keys
  if (code.startsWith("Digit")) {
    return code.slice(5) // "Digit1" -> "1"
  }
  // Numpad keys
  if (code.startsWith("Numpad")) {
    const num = code.slice(6)
    if (num.match(/^\d$/)) {
      return "NUMPAD" + num
    }
    return "NUMPAD" + num.toUpperCase()
  }
  // Function keys (F1-F12)
  if (code.match(/^F\d+$/)) {
    return code
  }
  // Special keys
  const specialKeys = {
    "Space": "SPACE",
    "Enter": "ENTER",
    "Tab": "TAB",
    "Escape": "ESC",
    "Backspace": "BACKSPACE",
    "Delete": "DELETE",
    "Insert": "INSERT",
    "Home": "HOME",
    "End": "END",
    "PageUp": "PAGEUP",
    "PageDown": "PAGEDOWN",
    "ArrowUp": "UP",
    "ArrowDown": "DOWN",
    "ArrowLeft": "LEFT",
    "ArrowRight": "RIGHT",
    "CapsLock": "CAPSLOCK",
    "NumLock": "NUMLOCK",
    "ScrollLock": "SCROLLLOCK",
    "PrintScreen": "PRINTSCREEN",
    "Pause": "PAUSE",
  }
  return specialKeys[code] || code.toUpperCase()
}

// Custom hooks for LiveView
const Hooks = {
  KeystrokeCapture: {
    mounted() {
      // Focus the element immediately when mounted
      this.el.focus()

      this.handleKeydown = (e) => {
        // Prevent default browser actions
        e.preventDefault()
        e.stopPropagation()

        // Ignore modifier-only key presses (wait for actual key)
        if (["Control", "Shift", "Alt", "Meta"].includes(e.key)) {
          return
        }

        // Build the keystroke string
        const modifiers = []
        if (e.ctrlKey) modifiers.push("CTRL")
        if (e.shiftKey) modifiers.push("SHIFT")
        if (e.altKey) modifiers.push("ALT")

        const key = normalizeKey(e.code)
        const keystroke = [...modifiers, key].join("+")

        // Send to LiveView
        this.pushEventTo(this.el.getAttribute("phx-target"), "keystroke_captured", {
          keystroke: keystroke
        })
      }

      this.el.addEventListener("keydown", this.handleKeydown)
    },

    destroyed() {
      this.el.removeEventListener("keydown", this.handleKeydown)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
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

