// The phone's outbox of entries made without signal (kept in localStorage). Entries the office
// rejected stay here, marked failed, until the person on the phone has seen them.
const KEY = "hisaab-outbox"

export function all() {
  try { return JSON.parse(localStorage.getItem(KEY) || "[]") } catch (_) { return [] }
}
const save = (items) => localStorage.setItem(KEY, JSON.stringify(items))

export const pending = () => all().filter(i => !i.error)
export const failed = () => all().filter(i => i.error)

export function enqueue(item) {
  save([...all().filter(i => i.client_uuid !== item.client_uuid), item])
}

export function remove(uuid) { save(all().filter(i => i.client_uuid !== uuid)) }

export function markFailed(uuid, error) {
  save(all().map(i => i.client_uuid === uuid ? { ...i, error } : i))
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
