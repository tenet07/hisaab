// Hisaab offline support: the phone app's pages and assets stay usable without signal.
const VERSION = "hisaab-v2"
const SHELL = ["/m", "/m/offline"]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL).catch(() => {})).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()))
})

self.addEventListener("fetch", (event) => {
  const req = event.request
  const url = new URL(req.url)
  if (req.method !== "GET" || url.origin !== location.origin) return

  // fingerprinted assets never change: cache first
  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      const copy = res.clone()
      caches.open(VERSION).then((c) => c.put(req, copy))
      return res
    })))
    return
  }

  // phone app pages: fresh when online, last copy when not
  if (url.pathname.startsWith("/m")) {
    event.respondWith(fetch(req).then((res) => {
      if (res.ok && res.type === "basic" && !res.redirected) {
        const copy = res.clone()
        caches.open(VERSION).then((c) => c.put(req, copy))
      }
      return res
    }).catch(() => caches.match(req, { ignoreVary: true }).then((hit) => hit || caches.match("/m/offline", { ignoreVary: true }))))
  }
})
