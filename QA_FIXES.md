# QA fixes (20 Oct 2026)

Every Critical and High finding in QA_REPORT.md is fixed, with a regression test in
`test/models/qa_regressions_test.rb` where it touches money or stock.

| # | Fix |
|---|---|
| C1 | An owner approval is tied to the exact order value; any edit to the lines voids pending/approved approvals. |
| C2 | Opening balances are open items: FIFO pays them first, they age, show in dues/overdue/reminders. A negative opening balance is an opening advance that pays new bills. |
| C3 | One price rule everywhere (`Customer#prices_include_tax?`: walk-in/retail tier = GST-inclusive, dealers = rate + GST). The counter screen re-prices rows when the customer changes. |
| H1 | A quoted invoice must belong to the customer and contain the product. |
| H2 | Pieces with a pending write-off can't be batched; sending a claim voids pending write-offs; write-off checks the piece is still in the shop. |
| H3 | Offline entries the server rejects stay on the phone in a red "not accepted" box (with any cash entered) and appear on the owner's dashboard. |
| H4 | Cheque/UTR reference field on the delivery screen. |
| H5 | Failed drops can be taken off a route and re-planned (history kept in the audit trail); a failed drop no longer blocks cancellation. |
| H6 | Credit notes credit back exactly what was billed for those pieces; a full return includes the round-off and nets to zero. |
| H7 | Counter cash/UPI settles the bill it was paid for; walk-in bills can't be put on credit from the invoice screen. |
| H8 | Cost prices only for owner/accounts/purchases; counter sees only their own bills, no dues; delivery has no payments or balances; salesmen see only their markets. |
| H9 | Phone app checks orders/payments/replacements/deliveries permissions per action and per synced item. |
| H10 | Credit-limit hold: counter/invoice refuse with a clear message; orders go to the owner as a "Bill over credit limit" approval. |
| H11 | Invoices from a GST period that may be filed (after the 10th of the next month) can't be cancelled — use a credit note. |
| H12 | B2C-small credit notes are netted in GSTR-1 table 7; B2CL credit notes have their own CDNUR table; unknown tables 404. |
| Medium | E-way check on auto-planning; returns only restock to sellable; rate-difference capped; discounts 0–100 and whole-number quantities enforced; quantity cap; counter can't open ledgers; CA/counter can't send statements; no future dates; WhatsApp only makes orders when a product matches, understands "dozen"/"stop."; outstanding computed in SQL (pages went from ~800 queries to ~40); rejected write-offs return the piece to the claim queue. |
| Low | Bounce only for cheques; clearer cheque-reference hint; friendly amount errors; dead routes removed; 390px overflow fixes; delivery app marks unstarted routes; OTP locks after 5 wrong tries; count adjustments above ₹5,000 need the owner by default; HSN UQC from the product unit; login rate limit per person, not per shop router. |
