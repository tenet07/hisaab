# Hisaab QA report

**Date:** 20 Oct 2026. **Build:** the dev server on localhost:3000, with the seeded demo shop.
**Method:**
- Ran the real UI with Playwright: desktop at 1440×900, phone at 390×844, offline via `context.setOffline`.
- Sent direct HTTP requests as each role, using that role's session cookie and CSRF token.
- Ran service objects in `bin/rails runner`. Destructive edge cases ran inside transactions that were rolled back.
- Ran a ledger invariant checker after each batch of actions: balance = sum of the ledger, and outstanding invoices − unallocated payments + opening balance = balance.
- `bin/rails test` passes: 27 runs, 0 failures.

The application code was not changed. Every finding below was reproduced. Scripts and screenshots are in
`/tmp/claude-0/-home-user/83644908-d75a-52d1-86ee-532fb841768d/scratchpad/qa-hisaab/`.

---

## Critical

### C1. After the owner approves a discount, the order can be edited to any discount and billed with no new approval
- **Steps:**
  1. As salesman (amit@), `POST /orders` for customer 9 with HV-FAN48 × 2 at `discount_pct=15`. This creates ORD/2026-27/00025.
  2. As accounts, `POST /orders/26/convert`. The app answers "A discount is above 10% — sent to the owner for approval."
  3. As owner, approve the request in `/approvals`.
  4. As salesman, `PATCH /orders/26` and change the same line to `discount_pct=95`. The app answers "Saved."
  5. As accounts, `POST /orders/26/convert`.
- **Expected:** editing an order after approval cancels the approval. Or the approval is tied to the approved amount or discount.
- **Actual:** INV/2026-27/00108 is posted with the fan at 95% off. It totals ₹281.00 instead of about ₹5,617 (2 × ₹2,380 + GST).
- **Cause:**
  - `app/controllers/orders_controller.rb:83` only checks that *some* approved `discount` approval exists for the order.
  - `orders_controller.rb:50-63` (`update`) still allows edits while the order is `confirmed`, including after approval.

### C2. Opening balances are never matched to payments, so dues, ageing and "paid" status are wrong for migrated customers
- **Steps:**
  1. Create a customer with `opening_balance=1000`. In the run-through this was customer 27 "QA FIFO Traders", made via `POST /customers`.
  2. Post two invoices: ₹694 and ₹347.
  3. Record a ₹2,000 cheque and ₹500 cash.
- **Actual:**
  - Customer page "Advance" shows **₹1,459**. The ledger balance is ₹459 Cr, because the ₹1,000 opening debt is ignored by FIFO.
  - The next invoice (₹694) is auto-settled from that phantom advance and shows **paid**, even though the customer then owes ₹235.
- **Rollback repro:** opening ₹5,000, pay ₹1,000, new ₹694 invoice. Result: `balance=4694`, invoice `outstanding=0 state=paid`, `open_invoices=0`, ageing total `0`.
- **Impact:** every customer imported with an opening balance is affected. They disappear from the dues and ageing reports, the overdue dashboard and WhatsApp overdue reminders. Their payments show as "advance" and auto-pay new bills.
- **Cause:**
  - `app/services/payments/allocate.rb:6-23` only matches against invoices.
  - `app/models/customer.rb:62` `unallocated_paise` ignores opening entries.
  - The dues and ageing code is invoice-based: `customer.rb` `open_invoices`/`ageing`, and `reports_controller.rb#dues`.

### C3. The counter screen shows one price and posts a different one, and the same dealer pays a different price at the counter than on the invoice screen
- **Steps (UI, as counter@):** `/counter` → tap the "Stellar Bright LED Bulb 9W" tile twice. The rate shows ₹102 (retail) and the total ₹204.
  1. Pick customer "Bombay Electric Stores" (wholesale tier, no GSTIN). The rate stays **₹102** and the total stays **₹204**. Bill on Credit.
     - Posted INV/2026-27/00103 = **₹124**.
  2. Pick "Royal Lighting" (GST-registered). The badge changes to "Prices + GST (B2B)" and the screen shows **₹114**.
     - Posted INV/2026-27/00104 = **₹69**.
  3. Same dealer, 10 × PH-B9:
     - `POST /counter` gives INV/2026-27/00095 = **₹620**, tax-inclusive.
     - `POST /invoices` gives INV/2026-27/00096 = **₹694**, GST added on top.
- **Expected:** the on-screen total equals the posted bill. A dealer's price does not depend on which screen bills them.
- **Cause:**
  - `app/javascript/controllers/lines_controller.js:57-63` changes the tier and the inclusive flag but never re-prices existing rows. Counter users cannot edit rates, so the server uses the tier price.
  - `app/controllers/counter_controller.rb:23` makes every bill to an unregistered dealer tax-inclusive (`inclusive: !customer.b2b?`).
  - `invoices_controller.rb:45` is always tax-exclusive. 14 of the 20 seeded dealers have no GSTIN.

---

## High

### H1. Warranty check can be bypassed by quoting any invoice
- **Steps:**
  1. As counter@, check `/replacements/warranty?customer_id=5&product_id=14`. It returns `valid:false`: the customer never bought WP-SW6.
  2. `POST /replacements` with `customer_id=5, product_id=14, outcome=swapped, invoice_id=111`. Invoice 111 is another customer's counter bill and contains only PH-B9.
- **Actual:** RPL/2026-27/00012 is created with `warranty_valid=true`. A good piece leaves sellable stock and the defective one enters the claim queue. The brand later "replaced" it.
- **Cause:**
  - `replacements_controller.rb:33` loads any invoice by id.
  - `replacements/intake.rb:26,50` (`lookup_on`) never checks that the invoice belongs to the customer or contains the product.

### H2. Write-off approval and brand claim race corrupts the stock buckets
- **Steps:**
  1. As accounts, `POST /replacements/6/write_off`. RPL6 is SY-BT20, awaiting claim. An approval is created.
  2. Batch Syska pieces 3, 5 and 6 into a claim (CLM/2026-27/00002) and send it (challan CH-QA-1).
  3. As owner, approve the pending write-off.
- **Actual:**
  - SY-BT20 buckets show **awaiting_claim −1, with_brand 3**. Only 2 are really with the brand.
  - RPL6 is `written_off` while still on the claim.
  - After settling 3 (replaced) and 5 (credited), the claim reports "Claim fully settled" but with_brand stays at 1 forever.
  - The dashboard shows "2 pcs with brands".
- **Cause:** `app/services/approvals.rb:27-33` moves `awaiting_claim → written_off` without checking `claim_status`. `Claims::Batch.build` and `dispatch!` (`claims/batch.rb`) do not exclude pieces with a pending write-off.

### H3. An offline delivery rejected at sync is silently discarded, including the cash collected
- **Steps (phone, delivery@, 390px):**
  1. Open `/m/drops/9`, then `setOffline(true)`.
  2. Enter a wrong OTP `1111` and Amount `2000`, then tap Delivered. The alert says "No signal — saved on this phone…".
  3. Go back online.
- **Actual:** a 4-second toast says "Couldn't sync: OTP doesn't match…". The outbox is then **emptied**. The drop stays `pending` and no ₹2,000 receipt exists. Nothing on the phone or the desktop shows that it was lost.
- **Cause:**
  - `app/controllers/m/sync_controller.rb:31-33` marks every validation error `permanent: true`.
  - `app/javascript/controllers/outbox_controller.js:48` then removes the item.
  - The OTP is not checked before queuing offline: `outbox_form_controller.js:17-21`.

### H4. Cheque collection at a drop is impossible
- **Steps:** on `/m/drops/9`, enter the correct OTP, Amount 5000, pick **Cheque**, then tap Delivered.
- **Actual:** "Reference is needed for a cheque or UPI (cheque no. / UTR)". The form has no reference field (0 `input[name=reference]`), so the drop cannot be closed with a cheque. Offline, it falls into H3 and is lost.
- **Cause:** `app/views/m/route/drop.html.erb:34` offers Cash/UPI/Cheque with no reference input. `payment.rb` requires a reference for cheques.

### H5. A failed delivery can never be re-dispatched or cancelled
- **Steps:** on the phone, open `/m/drops/10` → "Not delivered" (Shop closed). INV/2026-27/00086 is now `failed`.
- **Actual:**
  - `Invoice.undispatched` excludes it, so it never shows in "pending" or auto-plan again. A unique index stops a second Delivery.
  - It can't be removed from the run: "Delivered drops can't be removed".
  - Cancelling the invoice fails with **"Delivered already — issue a return credit note instead"**.
- **Cause:**
  - `app/models/delivery.rb:10` `done? = status != "pending"` treats `failed` as done.
  - `invoice.rb:19` `undispatched` uses `where.missing(:delivery)`.
  - `invoicing/cancel.rb:17` and `dispatch_runs_controller.rb:48` both rely on `done?`.

### H6. Credit notes can't fully reverse an invoice (round-off)
- **Steps:**
  1. Accounts → `/invoices/128/credit_notes/new` (INV/2026-27/00105: 10 × PH-B9, round-off −₹0.40). Return all 10.
     - Result: **"Credit exceeds what is still owed on this invoice"**. A full return is impossible.
  2. Repeat on INV/2026-27/00006 (round-off +₹0.20).
     - The CN totals ₹940.80 against a ₹941 bill. In the rollback test, a +₹0.12 invoice stayed **"part-paid", ₹0.12 outstanding**, and would keep appearing in dues and overdue lists.
  3. A discounted line (3 × ₹62 at 3.3%) also fails a full return, because of per-piece rounding.
- **Cause:** `app/services/invoicing/credit_note.rb:26,33-34`. The CN re-computes from a rounded per-piece taxable and uses `exact_paise`. It ignores the invoice round-off and does not credit back the line's actual taxable/tax.

### H7. Walk-in cash sales show as unpaid (one shared CASH customer plus FIFO)
- **Steps:**
  1. As counter, `POST /invoices` with `customer_id=22` (Cash customer). This is allowed, and posted INV/2026-27/00110 on credit.
  2. Make a normal walk-in cash sale on `/counter`. This gave INV/2026-27/00111, ₹136, paid cash.
- **Actual:**
  - INV 00111 shows **unpaid**: its receipt was FIFO-applied to an older CASH invoice.
  - Earlier, the PDF of a fully paid walk-in bill (INV 00100) printed **"Scan to pay ₹408.00 by UPI"**.
- **Cause:**
  - `invoices_controller.rb#create` has no walk-in-on-credit guard. Only `counter_controller.rb:28` has one.
  - `counter_controller.rb:26` records the payment against the customer instead of matching it to the bill just posted.

### H8. Counter and salesman can read cost prices; delivery and salesman can read any customer's dues and all payments
- **Steps:**
  - As counter@, GET `/counter`, `/invoices/new` or `/orders/new`. The page source contains `"purchase":20500` for all 14 products. This is the same as amit@ on `/orders/new` and `/m/orders/new`.
    - Cause: `app/helpers/catalog_helper.rb:7`.
  - As delivery@:
    - `/m/catalog` returns `balance` for all 22 customers (`m/sync_controller.rb:9`).
    - `/m/customers/8` shows "Amount due ₹40,822, ₹10,049 overdue" for any customer.
    - `/payments` and `/payments/:id` list all 68 receipts. `delivery` has `:payments`, and `PaymentsController` index and show are only gated on that.
  - As amit@: `/m/customers?all=1` and `/m/customers/8` (Imran's customer) show dues. `/payments` lists everyone's receipts.
  - As counter@:
    - `/customers/13?dues=1` returns "Balance ₹1,78,666.20" plus unpaid bills for any customer (`customers_controller.rb:19`).
    - `/customers?owing=1&sort=balance` filters and sorts by the hidden balance (lines 14-15).
    - `/invoices` and `/payments` list all customers' bills and receipts with outstanding amounts.
- **Expected (README):** counter has "no margins, no other customers' ledgers", and delivery has "no ledgers".

### H9. Delivery staff can create orders and replacements
- **Steps:** as delivery@:
  - `POST /m/orders` created ORD/2026-27/00006.
  - `POST /m/replacements` created RPL/2026-27/00008.
  - `/m/sync` with `kind: order` created ORD/2026-27/00010.
- **Cause:** `M::OrdersController`, `M::ReplacementsController` and `M::SyncController#push` only check `:mobile`. They never check `:orders` or `:replacements` (`app/controllers/m/base_controller.rb:9`).

### H10. Credit limits are never enforced
- **Steps:** Balaji Light House (customer 13) owes ₹1,71,526 against a ₹50,000 limit. As counter, `POST /counter` with `pay_mode=credit` for HV-FAN48 × 3.
- **Actual:** INV/2026-27/00109 (₹7,140) is posted with no warning or approval. A `credit_limit` approval kind exists (`approval.rb`) but nothing creates it. Grep shows `over_credit_limit?` is only used for display (`orders/show.html.erb:50`, `customers/show.html.erb:19`).

### H11. Cancelling a past-month invoice rewrites that month's filed GSTR-1
- **Steps (rolled back):** cancel INV/2026-27/00002 (dated 15 Sep) today.
- **Actual:** September GSTR-1 taxable drops from ₹7,36,745.00 to ₹6,56,195.00 and B2B/B2CS lose the invoice. October 3B is unchanged. No current-period adjustment is produced.
- **Cause:**
  - `reports/gstr1.rb:19` filters `Invoice.posted` by `invoice_date`.
  - `invoicing/cancel.rb` allows cancelling any age of invoice.

### H12. GSTR-1 omits credit notes on B2C invoices, so GSTR-1 and 3B disagree
- **Steps:** October has CN/2026-27/00001 (₹290 taxable shortfall) on an unregistered customer.
- **Actual:**
  - GSTR-1 B2CS taxable is ₹6,48,129.97, not reduced.
  - `cdnr.csv` is empty. There is no `cdnur` table: `TABLES` at `reports/gstr1.rb:89` omits it, and `?table=cdnur` silently returns the B2B CSV.
  - GSTR-3B 3.1(a) nets the CN: ₹9,14,993.97 vs GSTR-1 ₹9,15,283.97.

---

## Medium

### M1. Auto-planning a dispatch run skips the e-way bill check
- **Steps:** accounts, `POST /dispatch_runs` with `market_id=5, auto=1`.
- **Actual:** INV/2026-27/00074 (`eway_required=true`, no e-way no.) is loaded onto run 3. The manual `add` action blocks this (`dispatch_runs_controller.rb:41`). Auto (`:18-20`) does not.
- **Also:** positions come out as 0, 2, 4, …, 12 (`run.deliveries.size + i`).

### M2. Pieces can go into buckets they can never leave
- **Customer return to `with_brand`:** `POST /invoices/128/credit_notes` with `restock_bucket=with_brand` was accepted (CN/2026-27/00003). The piece sits in "with brand" with no claim. The param is not checked against the UI list (`credit_notes_controller.rb:33`).
- **Return to "Awaiting brand claim":** this creates stock in `awaiting_claim` with no `Replacement`, so it can never be batched into a claim. Claims are built from Replacement rows.
- **Desktop shortfall:** the UI default is "No stock movement (never left the shop / short delivery)" (`credit_notes/new.html.erb:7`). Stock was already deducted at invoicing, so short pieces vanish. CN/2026-27/00004 (2 pcs) left PH-B9 sellable unchanged at 223. A phone shortfall correctly restocks them (`dispatch/drop.rb`).

### M3. Rate-difference credit notes can exceed the line value
- **Steps:** a rate-difference CN of `rate_paise=100000` × 2 on a ₹138.88 line was accepted with total ₹2,240. It is only capped by the invoice total (`invoicing/credit_note.rb:26,34`).

### M4. Negative discounts and out-of-range discounts are accepted on bills
- **Counter:** `POST /counter` with `discount_pct=-50` gave INV/2026-27/00097 at ₹93 for a ₹62 item. Counter staff can surcharge with no approval; `over_discount_limit?` only checks for too much discount.
- **Owner:** `discount_pct=150` on one line, or `rate=-50` (rolled back), posts a negative line inside a positive invoice.
- `OrderLine` validates 0..100, but `InvoiceLine` has no validations (`app/models/invoice_line.rb`, `concerns/line_items.rb:20`).

### M5. Decimal quantities are silently truncated, and the preview disagrees
- **Steps:** at the counter, set qty `1.9` on the phone or UI.
- **Actual:** the JS total shows ₹194 (it uses `parseFloat`). The posted bill is for 1 piece (`to_i`, `line_items.rb:17-20`). Nothing tells the user.

### M6. Huge quantities return HTTP 500
- `POST /orders` with quantity `99999999999` as counter fails with `ActiveModel::RangeError`. The owner's `/invoices` with `allow_negative=1` and qty 3e9 does the same. Quantity columns are int4 with no bounds check.

### M7. Counter staff with `?tab=ledger` get HTTP 500
- `/customers/1?tab=ledger` as counter@ returns a 500. `@entries` is nil because `can?(:ledgers)` is false, but the view still renders the ledger branch (`customers/show.html.erb:31,47-49`).

### M8. CA, the read-only role, can trigger WhatsApp sends
- As ca@, `POST /customers/1/send_statement` returned "Statement sent on WhatsApp." A `monthly_statement` message was queued. `CustomersController#send_statement` has no `require_writer!` (`customers_controller.rb:63`). Counter can also do this for any customer.

### M9. Invoices and payments can be future-dated
- Owner `POST /invoices` with `invoice_date=2031-03-01` posted **INV/2030-31/00001**, opening a new FY sequence. A payment dated `2031-01-01` was also accepted. `date_param` has no upper bound (`invoices_controller.rb:45`, `payments_controller.rb`).

### M10. The WhatsApp order parser makes junk orders and misleading replies
Run through Simulate as customer 9:
- **"payment kar diya 5000"** → order ORD-00024 with an unmatched line × **5000**. The customer gets "Got your order … “payment kar diya 5000” (we'll check) × 5000".
- **"kal 10 baje aana"** (come tomorrow at 10) → an order × 10 with an acknowledgement.
- **"call me at 5pm"** and **"Philips 9W bulb fifty"** → empty draft orders in the queue with no reply. The queue badge is inflated (23).
- **"philips 12w 2 dozen"** → qty 2 (should be 24).
- **"stop."** and **"Stop please"** → not recognised and no reply. Only exact `stop` or `unsubscribe` opts out (`whatsapp/inbound.rb:7`).
- **Cause:** `order_like?` treats any digit as an order (`inbound.rb:36`). The ack is sent even when no line matched a product.
- **Worked well:** "Philips 9W bulb 50 pc, 20W batten 10", Hinglish "bhai 9w philips 50 pc aur 20w batten 10 bhej do", multi-brand lines and newline lists.
- The Claude path was not exercised: the server has no `ANTHROPIC_API_KEY`, so only the fuzzy matcher was tested.

### M11. The dashboard, invoice list and dues report run N+1 queries over every invoice
- With about 130 invoices: `/` took 1,070 ms with 818 queries, `/invoices` 1,327 ms with 984 queries, and `/reports/dues` about 590 ms with 530 queries.
- `Invoice#paid_paise` and `credited_paise` call `.sum`, which ignores the `includes` preload (`invoice.rb:27-29`, `dashboard_controller.rb:12`). Every posted invoice ever is loaded. These pages will slow down linearly with history.

### M12. A rejected write-off strands the piece
- **Steps:** Wipro claim CLM/2026-27/00003, RPL2 settled "rejected". Owner rejects the write-off approval.
- **Actual:** the piece stays `claim_status=rejected` in `awaiting_claim`. It can't be re-batched, because `Replacement.awaiting` requires `awaiting`. The only option is to request a write-off again.

---

## Low

- **L1. Bounce is allowed on cash payments.** `POST /payments/70/bounce` on a cash receipt succeeded. The UI hides the button, but `payments/bounce.rb` doesn't check `mode`.
- **L2. Counter "UTR / cheque no." is marked optional but is required for cheques** (`counter/new.html.erb:51`). The validation message says "cheque or UPI", but only cheque is enforced (`payment.rb`).
- **L3. Raw error messages reach users:**
  - Discount 100% → "An entry is either a debit or a credit, above zero".
  - rate/amount `abc` → `invalid value for BigDecimal(): "abc"`.
- **L4. Dead routes return 404:** `/counter/lookup`, `/customers/:id/visit`, `/whatsapp/messages/:id` (`config/routes.rb`).
- **L5. Desktop pages overflow at 390px:**
  - `/` is 517px wide: "Sales, last 14 days" card header.
  - `/counter` is 674px: the line table squeezes the item input to one character.
  - `/orders` is 458px: the tab bar.
  - Salesmen can reach `/orders` and `/stock` in this layout.
- **L6. The delivery app shows routes that haven't started.** `/m/route` lists planned runs whose OTPs haven't been sent (Dadar run 1, `status=planned`), and the drop can be closed by photo.
- **L7. Owner's 4-digit drop OTP has no attempt limit or lockout** (`dispatch/drop.rb`). It can be brute-forced by a holder of the phone, up to 10k tries.
- **L8. Count adjustments never need owner approval by default.** `writeoff_approval_paise` defaults to 0 = "always allowed" (`stock/count.rb:25`). An accounts user posted −500 pcs with no approval (rolled back).
- **L9. GSTR-1 HSN UQC is hard-coded to PCS**, including for 90 m wire coils (`reports/gstr1.rb`).
- **L10. Login rate limit is 10 attempts per 3 minutes per IP** (`sessions_controller.rb:3`). Several staff behind one shop router can lock each other out.
- **L11. A double-click on "Bill & finish" logs a JS error** (`TypeError: Failed to fetch` from Turbo's aborted request). It is harmless; only one invoice was created.

---

## What passed
- **GST math:**
  - Intra-state CGST/SGST split.
  - Inter-state IGST: GSTIN 24 → POS 24, INV 00089 correct on the PDF.
  - B2C tax-inclusive back-calculation: ₹99 → taxable ₹88.39 + ₹10.61.
  - Odd-paise CGST/SGST split.
  - Whole-rupee round-off, amount in words, HSN summary.
- **Ledgers:** append-only triggers. The ledger invariant held after every flow except the stock-bucket corruption in H2.
- **Payments:** FIFO allocation across invoices, overpayment kept as advance, cheque bounce re-opening invoices, CN trim of over-allocations.
- **Idempotency:**
  - `/m/sync` replay and 5 concurrent identical syncs produced one receipt.
  - Offline order and offline OTP drop synced exactly once.
  - Double-tapping "Delivered" produced one receipt.
  - Double-clicking "Bill & finish" produced one invoice.
- **Phone drops:** wrong OTP online is rejected with a clear message. Photo proof works. A shortfall at drop creates a CN, restocks sellable and closes as `partial`.
- **CA:** every write endpoint tried was refused except M8. Covered: invoice, counter, payment, order, replacement, e-way, WhatsApp, dispatch, settings, supplier, stock count, customer, product, and `/m/*`.
- **Other roles:** counter cannot post credit notes or edit prices. Salesman rate overrides are ignored. Only the owner can approve.
- **Reports:**
  - GSTR-1 B2B/B2CS/HSN totals match the database: taxable ₹9,15,283.97, 57 invoices, 18 B2B.
  - Tally XML: 102 vouchers, all balanced.
  - The CA zip contains 13 files consistent with GSTR-1.
  - The GSTR-3B ITC split works.
- **Phone screens at 390px:** route, drop, visit, order, payment and replacement screens have no overflow.
- **JS errors:** none in the desktop crawl of 54 pages.
- **Offline:** cached pages load and the outbox badge works.

## Test data left in the dev database
- **Documents:**
  - INV/2026-27/00093–00111, INV/2030-31/00001
  - CN/2026-27/00001–00004
  - Receipts RCPT/2026-27/00055–00067 (approximately)
  - Orders ORD/2026-27/00006–00026
  - RPL/2026-27/00008–00012
  - Claims CLM/2026-27/00002–00003
  - Approvals 1–3
  - Dispatch run 3 (Vashi)
- **Customer:** C0022 "QA FIFO Traders …".
- **Simulated WhatsApp:** messages for Shiv Shakti Traders. Its marketing opt-in was turned off by STOP.
- **Stock:** SY-BT20 now has `awaiting_claim −1 / with_brand +1` from the H2 repro.
