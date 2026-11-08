# UX redesign notes

These notes cover the presentation and workflow changes in `/home/claude/shopos-ux`. Models, `app/services/books.rb`, `lib/shop.rb`, migrations, routes, param names and business rules are unchanged. Two controllers each got one read-only instance variable for display (listed at the end). `bin/rails test`: 52 runs, 0 failures.

Screenshots are in `tmp/ux-shots/` (`<screen>-390.png` / `<screen>-1280.png`, `dark-*` for dark mode, `e2e-*` for the end-to-end run). The before set is in `tmp/ux-before/`. To regenerate, run these on port 3100 against a freshly seeded DB:

```
python3 tmp/ux_shots.py tmp/ux-shots   # every screen, both widths, reports console/page errors
python3 tmp/ux_e2e.py                  # 2-item bill, payment, dispatch, delivery with code
python3 tmp/ux_dark.py                 # dark-mode spot checks
```

---

## 1. Design system

### Direction
The look is based on a switchboard: calm white surfaces on a cool grey background, a deep green for structure (the sidebar, the lead figure and primary buttons), and one amber indicator colour. Amber is used only for "this is where you are" or "this needs you": the active tab marker, low-stock and claim dots, and warning pills. Money is the most important thing on every screen, so rupees are large and bold, paise are smaller, and all figures use tabular digits.

### Tokens (`:root` in `application.css`, with a full dark-mode set under `prefers-color-scheme: dark`)

| Role | Light | Dark | Use |
|---|---|---|---|
| `--bg` | `#eef0ec` | `#0b1310` | page background |
| `--surface` / `--surface-2` / `--sunk` | `#fff` / `#f6f7f4` / `#e6e9e3` | `#121d18` / `#17241e` / `#0e1813` | panels, table heads, wells |
| `--ink` / `--ink-2` / `--ink-3` | `#15201a` / `#4b5851` / `#636f68` | `#e6ece8` / `#a9b6ae` / `#8b998f` | text, secondary text, faint text |
| `--brand` / `--brand-2` / `--brand-soft` | `#0f5132` / `#0b3d26` / `#e1efe6` | `#5cc48e` / `#0d2c1e` / `#173327` | primary actions, shell, selected states |
| `--lamp` / `--lamp-soft` / `--lamp-text` | `#f5b400` / `#fff2c4` / `#7a4a00` | `#f7c235` / `#3a2f0e` / `#f7d06a` | indicator: active nav, warnings |
| `--due` / `--ok` / `--info` / `--wa` | `#b42318` / `#147a3a` / `#1b5ea6` / `#0b7a3c` | lighter equivalents | money owed / received / info / WhatsApp |
| `--focus` | `#1b5ea6` | `#8fc0ff` | 3px focus ring on everything |

Contrast was checked for every text/background token pair in both themes. All pairs reach at least 4.5:1, and most are above 5.5:1. `--ink-3` was darkened to `#636f68` so faint text also passes on `--surface-2`.

- **Type:** a system UI stack (`Segoe UI Variable`, `system-ui`, Roboto, Noto Sans). It loads instantly on cheap Android phones and has a correct ₹ glyph. Google Fonts was blocked from this environment anyway. The scale is roughly 1.2: .78 / .875 / 1 / 1.125 / 1.35 / 1.75 / 2.25 / 2.75rem. The base is 16px, which also stops iOS from zooming into inputs.
- **Space:** a 4px grid (`--s1`…`--s10`).
- **Shape:** radii of 8 / 12 / 16px, used by hierarchy: inputs 8, buttons 12, panels 16. Pills are fully round.
- **Touch:** `--tap: 48px` for buttons, inputs and tabs. Secondary chips are at least 40px and list rows at least 60px. An automated audit at 390px found no undersized targets apart from inline text links.

### Components
- **App shell**
  - Phone/tablet (<960px): a slim top bar with an avatar menu (log out), plus a bottom tab bar. The tab bar shows 5 tabs per role, and the rest go behind "More" as a 3×3 sheet.
  - Desktop (≥960px): a fixed green sidebar with every section, plus who is logged in and a log-out button.
  - Delivery staff have one screen, so they get no tab bar.
- **Tabs per role**
  - Owner/Accounts/Counter: Today, Customers, New bill, Bills, plus More (Dispatch, Stock, Replacements, Claims, Markets, Tally).
  - Salesman: Shops, New order, Bills, Stock, Swaps.
- **`amt` helper:** shows a rupee figure as large rupees with small paise. Tones are `due` and `good`; sizes are `md`, `lg` and `xl`. There is a screen-reader copy of the full value. `rs0` gives whole rupees for dense summaries.
- **`icon` helper:** 24 inline SVG icons drawn as strokes, with no external assets.
- **Surfaces**
  - `.panel` for content.
  - `.stats` strip: one surface split by hairlines, with a dark green `.lead` cell for the figure that matters most.
  - `.list` with `.row-link` rows: touch rows with title, subtitle, amount on the right and a chevron.
  - `.tbl-wrap` tables for dense desktop data. `hide-sm`, `hide-md` and `only-sm` swap columns at phone width.
- **Controls**
  - `.btn` variants: primary, `-secondary`, `-ghost`, `-wa`, `-danger`, `-lamp`; sizes `-sm` and `-lg`; `-block`.
  - `.tile`: the salesman's 2×2 action grid.
  - `.seg`: radio buttons shown as one segmented control (Cash / UPI / Cheque, Wholesale / Retail).
  - `.chips`: quick amounts, date shortcuts, market filters.
  - `.stepper`: −/+ around a number input.
  - `.money-in`: ₹ prefix on amount inputs, with a `.big` variant.
  - `.search`: field with a search icon.
  - `.otp`: a large spaced 4-digit input.
- **Feedback**
  - `.flash` variants: ok, bad, wa (with an "Open WhatsApp" button), warn.
  - `.note` callout.
  - `.empty`: empty state with an icon, a one-line explanation and the next action.
  - `.pill` tones: ok, due, warn, info.
- **`.actionbar`:** a sticky bottom bar. It sits above the tab bar on phones and is inline on desktop. It holds the live total and the primary action for the bill form, load check and hand-over.
- **Print:** the print layout reuses the `.doc` bill styles. Navigation, flashes and action bars are hidden by `@media print`.

### Stimulus controllers (in `app/javascript/controllers`, auto-registered)
- `bill`: the bill builder (see 3.1).
- `fill`: one-tap amount chips.
- `stepper`: −/+ buttons, clamped to min/max.
- `handover`: shows "why short?" only for short items, sets the button label, and requires proof before submit.
- `range`: Tally date presets.

---

## 2. Friction points found (audited at 390px and 1280px) and what changed

| Screen | Friction before | Change |
|---|---|---|
| **All / nav** | The top nav wrapped to 2–3 lines on phones, or became a hidden horizontal scroll (the 390px shot showed "Tod…" cut off). There was no sense of place, and log-out was a tiny underlined link. | Bottom tab bar on phones with an amber active marker, a "More" sheet, and short labels where needed ("Swaps"). Sidebar on desktop. Log out moved into the avatar menu. Skip link and visible focus ring added. |
| **Login** | A `<select>` of "Name (role)" followed by a PIN box: two fiddly controls on a phone. | Name tiles in a 2-column grid (one tap), and a large centred numeric PIN field. It still posts `user_id` and `pin`. |
| **Today** | Four equal cards, then three tables of the same weight. Nothing said what needed attention, and the over-limit table overflowed at 390px. | The question "How are we doing" is answered by the stats strip: Sales today as the lead figure, then Collected (cash vs UPI), Customers owe and Deliveries open. "Needs you" is a prioritised list of over-limit shops, low stock, unassigned or failed deliveries, pieces to claim and pieces still with brands, each linking to the fix. There is an all-clear state when nothing needs attention. Due by market is now sorted by amount and drawn as bars. |
| **Customers** | Search was a text box, a market select and a "Find" button. The table hid useful columns on phones. The salesman landed here but tapping a name opened the accounts ledger instead of the visit screen. | A big search field plus horizontally scrolling market chips (one tap to filter). Touch rows show the shop, market, balance (red when owed) and an "Over limit" pill. **Salesmen now tap straight into the visit screen.** There is an empty state with "Clear search". |
| **Customer ledger** | Six equal buttons, five identical ageing cards, and a 7-column ledger that scrolled sideways at 390px. | A large balance with an ageing bar (0–30 / 31–60 / 61–90 / 90+). One primary action (New bill), then Record payment and WhatsApp reminder; Edit and Statement are moved to the header. On phones the ledger collapses debit and credit into one signed Amount column and fits the screen. Unpaid bills show "N days ago". |
| **Salesman visit** | Good bones, but recording a payment meant opening another page and typing the amount. "Oldest unpaid" was buried in grey text. | The balance is the hero, with a facts list underneath (oldest unpaid bill, its due amount and age; last payment). There is a 2×2 tile grid: **New order**, **Record payment**, **Replacement**, **WhatsApp reminder**. **Collect payment is inline on the same screen.** One-tap chips ("Oldest bill ₹2,500" / "Full ₹13,238") fill the amount, and Cash/UPI/Cheque is a segmented control. Before, taking a payment was tap, open page, type the amount, open a select, save. Now it is tap a chip, then save. There is also a Call button. |
| **New bill** | Eight fixed rows of 80+-option `<select>`s, no prices, no running total, and no warning for oversell until the server error came back. Customer was another long select. | **A searchable bill builder.** Customer search by name, market or phone shows the balance and price tier. Item search matches tokens ("syska 9w", "mcb"); arrow keys and Enter, or a tap, add the item, and adding the same item again bumps its qty. Each line has a qty stepper, an optional ₹ discount and a remove button. It shows the unit price for the customer's tier, the GST note and a live line total. Lines warn inline about "Only N in stock" and about a discount larger than the item value. Taxable / GST / round-off totals and a **sticky live bill total** stay with the Save button. Save is disabled until the bill is valid, with a reason as a tooltip. There is a credit-limit heads-up; it only warns and does not block. "Deliver" follows the customer's tier until the user touches it. The preview uses the same half-up maths as `Shop::GST`, and the e2e run checks that it matches the saved bill. The form still posts `customer_id`, `items[n][product_id|qty|discount]` and `deliver`. |
| **Bill view** | It was a document table only, at 390px it scrolled sideways, and actions sat at the bottom. | WhatsApp and Print are in the header. On phones a stacked line-item view replaces the 8-column table. A delivery side panel shows status, date, person and the customer code (office only, as before). "Cancel this bill" is a collapsed disclosure. The e-way bill and cancelled banners are styled as alerts. |
| **Bill print** | Fine. | Same structure, with a print bar that is hidden on paper. |
| **Bills list** | A date input and a "Show" button only. | Previous day / Today / Next day chips, and the date picker submits on change. The day summary is a stats strip. Rows show the customer first, with pills for cancelled and e-way bill. Empty state added. |
| **Stock / product** | Bare numbers, and "low" was a small pill. | Search field. On-shelf count is large and turns red when low. Brand and SKU are on two lines. The product page has bucket stats ("On shelf" instead of "Sellable"), the Goods received and Physical count forms side by side, and movements coloured +green / −red. |
| **Replacements** | Plain table. | Touch list with in-warranty / owner-approved pills, labelled form fields, `max=today` on "sold on", and an empty state. |
| **Claims** | Inline styles, and the brand cards had no hierarchy. | "Ready to send" brand cards with piece-count pills and one button each. The claims list shows "N open" or "Settled". The settle form uses 3 labelled number fields in one row. |
| **Dispatch** | A dense table where each row had a select, a date and a Save button, and it wrapped badly at 390px. | Grouped by market. Each stop is a row with shop, bill and value, a status pill and inline plan controls. There are day chips, a "N not assigned" count in the header, a "Carried over" pill, and Reschedule uses the amber button. |
| **Delivery run** | Three equal cards, and stops were plain cards. | A big "Stops left" figure with a progress bar, Delivered, and Cash to hand in. Stops are large rows (≥76px) with a status pill and the next step ("Load check" / "Hand over"). An "All stops done" empty state tells them what to do next. The code never appears (asserted in the e2e run). |
| **Delivery stop** | Load check and hand-over used small number inputs in tables. Every item always showed two extra short and damaged fields. Code and photo had equal weight. | A two-step indicator (Load check → Hand over). Counts are pre-filled with ±steppers, and there is one sticky "All loaded" button. In **hand-over, the default path is: type the 4-digit code, then tap Delivered.** The "Why short?" and "damaged" fields only appear for an item that has been lowered; the row turns amber, the reason becomes required, and the button changes to "Partly delivered". Reason suggestions come from a datalist. Photo proof sits behind "No code? Take a photo instead". Submitting with no code and no photo is stopped in the browser with a message (the server still validates). Payment collected uses a big ₹ field with a Cash/UPI/Cheque segment. "Couldn't deliver?" uses reason chips instead of a select. There is a Call button. |
| **End of day** | A wall of text per person. | One card per person: cash to hand in and UPI/cheque as figures, outcome pills, the list of goods that should come back, or "Nothing to bring back". |
| **Markets / Tally / forms** | Plain tables and labels wrapping inputs. | Markets show a delivery-day badge in a touch list. Tally has "This month / Last month / Today" presets and import steps as a numbered checklist (a real sequence). All forms use labelled fields with hints ("optional", "0 means no limit"), ₹-prefixed money inputs, a Wholesale/Retail segment, and `inputmode` for numbers. |
| **Flash** | "Send receipt on WhatsApp →" as a bare link. | Icon flashes, and a WhatsApp flash with an "Open WhatsApp" button. |

---

## 3. Verification
- `bin/rails test`: 52 runs, 222 assertions, 0 failures, 0 errors.
- `tmp/ux_shots.py`: 25 screens × 2 widths. 0 console errors, 0 page errors.
- `tmp/ux_e2e.py`, run at both 1280 and 390 for the bill and with 0 errors, covers:
  - **Bill:** Counter makes a bill for Sharma Light House: Syska LED Bulb 9W × 12, plus Havells MCB × 2 with ₹10 off. The live preview was ₹1,251 and the saved bill was ₹1,251.00.
  - **Payment:** Ramesh opens Gupta Electricals from Shops, taps the "Oldest bill" chip, UPI, enters a reference and saves. He sees the "recorded" flash and the WhatsApp receipt button.
  - **Dispatch:** Accounts assigns Gupta's delivery to Delivery 1 for today.
  - **Delivery:** Delivery 1 opens the stop, taps All loaded, gives 2 short with a reason and damaged count, and tries to submit without a code (blocked). Then they enter the code and ₹2,000 cash and submit, reaching "Partly delivered" on the run. The code was asserted absent from the run, stop and hand-over pages.
- Dark mode was checked on Today, New bill, Visit and the stop screen at both widths.

---

## 4. Recommended but not built
1. **Payment allocation to a chosen bill.** Today payments always clear the oldest first (a business rule in `books.rb`). The "Oldest bill" chip matches this, but shops sometimes pay against a specific bill.
2. **Offline / poor-signal mode for delivery staff.** A service worker that queues load and hand-over posts. The PWA manifest exists but is still the Rails default (name "Shopos", theme colour red), which belongs to the other engineer's area.
3. **Recent / frequent items per customer in the bill builder.** "Reorder last bill" would remove most typing for repeat wholesale orders. This needs a small query, so it is a controller change.
4. **Server-rendered search for 500+ customers.** The bill picker embeds all customers as JSON (fine at 500, about 40KB). Beyond a few thousand it should become a Turbo-frame search endpoint.
5. **Barcode/QR scan to add items** on the counter, using the phone camera and `BarcodeDetector`.
6. **Hindi labels.** Out of scope per brief, but the copy is short and centralised enough to move to `config/locales` easily.
7. **Owner's week view on Today.** Sales and collections for the last 7 days as a small chart. This needs a grouped query in the dashboard controller.
8. **Dispatch bulk assign:** "Assign all Sadar Bazaar stops to Delivery 1" in one action. It needs a new route.
9. **Self-hosted webfont.** If the brand wants a distinctive display face, self-host a subset woff2 that includes the ₹ glyph, rather than using Google Fonts. Google Fonts was unreachable here, and the system stack is the right default for cheap phones.

### Controller touches (presentation only)
- `DashboardController#show`: adds `@runs` (open deliveries up to today), `@unassigned` and `@failed`, which are counts for the dashboard.
- `InvoicesController#new`: adds `@balances` (the same query `CustomersController#index` already uses) so the bill builder can show the chosen shop's balance and a credit-limit warning.
