import "phoenix_html"
import { Socket } from "phoenix"
import topbar from "../vendor/topbar"
import { LiveSocket } from "phoenix_live_view"
import 'bootstrap';

let Hooks = {}
Hooks.set_focus = {
  mounted() {
    this.el.focus();
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#003a3e" }, shadowColor: "rgba(0, 0, 0, .3)", barThickness: 1 })
window.addEventListener("phx:page-loading-start", info => topbar.delayedShow(200))
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()


// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// window.liveSocket = liveSocket
