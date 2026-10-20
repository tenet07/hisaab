// The phone's outbox of entries made without signal (kept in localStorage).
const KEY = "hisaab-outbox"

export function pending() {
  try { return JSON.parse(localStorage.getItem(KEY) || "[]") } catch (_) { return [] }
}

export function enqueue(item) {
  const items = pending().filter(i => i.client_uuid !== item.client_uuid)
  items.push(item)
  localStorage.setItem(KEY, JSON.stringify(items))
}

export function remove(uuid) {
  localStorage.setItem(KEY, JSON.stringify(pending().filter(i => i.client_uuid !== uuid)))
}

// "lines[12][product_id]" style names → nested objects, the shape Rails params would have
export function formToObject(fd) {
  const out = {}
  for (const [name, value] of fd.entries()) {
    if (name === "authenticity_token" || name === "_method" || value instanceof File) continue
    const keys = name.replace(/\]/g, "").split("[")
    let cur = out
    keys.forEach((k, i) => {
      if (i === keys.length - 1) cur[k] = value
      else cur = cur[k] ||= {}
    })
  }
  return out
}
