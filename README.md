# Hisaab — Shop Operating System

A shop OS for an electrical wholesaler, built on the plan's one rule: **two append-only ledgers** (stock
and customer). Every bill, delivery, payment, replacement and brand claim writes entries; nobody types a
stock count or a balance. Postgres triggers refuse UPDATE/DELETE on both ledgers — corrections are reversing entries.

## What's in it

| Area | Highlights |
|---|---|
| **Order queue** | WhatsApp, salesman and counter orders in one inbox. Paste/receive a message ("Philips 9W bulb 50 pc, 20W batten 10", Hinglish fine) → AI (Claude) parses to a draft with confidence per line → confirm with one tap → post invoice. Built-in fuzzy matcher when no API key. |
| **GST invoicing** | Serial per financial year (`INV/2026-27/00001`), CGST+SGST vs IGST by place of supply, HSN summary, round-off, amount in words, UPI QR, B2C tax-inclusive counter bills, e-way bill flag > ₹50k, e-invoice IRN via GST API provider, cancel-by-reversal, credit notes (shortfall/return/rate difference). |
| **Counter POS** | Tiles of best sellers + type-to-search, keyboard flow, walk-in cash/UPI or dealer credit, discount limit needs owner. |
| **Payments** | Cash/UPI/cheque/bank, FIFO allocation to oldest bills, advances auto-applied, cheque bounce reversal, WhatsApp receipt. |
| **Replacements & claims** | Warranty from the sale invoice; swap = two movements (sellable → awaiting_claim); brand claim batches with printable challan; partial credit-note matching; replacement pieces close the claim; no-response claims flagged after N days; write-offs need owner approval. |
| **Stock** | Buckets: sellable / awaiting_claim / with_brand / written_off. Purchases, rotating monthly counts with reasons, reorder levels from sales history. |
| **Dispatch** | Runs per market route; only billed invoices can be loaded; drag to order drops; OTP sent on WhatsApp; delivery proof by OTP or photo; shortfall → credit note; cash collected → receipt. |
| **Phone app** (`/m`) | Installable PWA for salesmen (visit screen: due, oldest unpaid, last 3 orders, open replacements, New order / Payment / Replacement) and delivery staff (today's route). Works offline: entries queue on the phone and sync with idempotent `client_uuid`s. |
| **WhatsApp** | Invoices (PDF), delivery done, receipts, credit notes, overdue reminders (daily), monthly statements, balance queries ("bal"), orders, opt-in market broadcasts. Meta Cloud API adapter + webhook; "log" provider for development. |
| **Owner** | Dashboard (sales/collections/dues by market, overdue, stock alerts, approvals, flagged claims, today's dispatch), approvals, broadcasts. |
| **Books** | Sales, dues & ageing, collections, day book, GSTR-1 (CSV per table + portal JSON), GSTR-3B, HSN, Tally XML, one-click CA month-end zip, audit trail (who / when / device). |

## Roles

Owner (everything) · Accounts (desktop, can't delete — only reverse) · Counter (billing, replacements, stock lookup; no margins, no other ledgers) ·
Salesman (phone; can't change prices or balances) · Delivery (route, proof, cash; no ledgers) · CA (read-only + exports). Customers use WhatsApp only.

## Run locally

```bash
bundle install
bin/rails db:setup        # creates, loads structure.sql (with triggers) and seeds a demo shop
bin/dev                   # http://localhost:3000 — demo logins on the sign-in page, password hisaab123
bin/rails test            # ledger, GST, FIFO, claims, dispatch, parser tests
```

Optional: `ANTHROPIC_API_KEY` (AI order reading), `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`,
`WHATSAPP_APP_SECRET` (WhatsApp Cloud API), `GST_API_URL` / `GST_API_KEY` (e-invoicing), `APP_HOST` (links in WhatsApp messages).

## Deploy (small server in India + daily backups)

1. A 2 vCPU / 4 GB VM in Mumbai or Hyderabad (AWS Lightsail, DigitalOcean BLR, E2E Networks…) with Docker.
2. `cp .env.example .env`, fill it in, then `docker compose up -d` (web, jobs, Postgres). Put Caddy or nginx in front for HTTPS.
3. Cron `bin/backup` nightly — Postgres dump + uploaded photos, 30 days kept, copied to an S3-compatible bucket when `BACKUP_S3_URI` is set.
4. In Meta's WhatsApp Manager, set the webhook to `https://<host>/whatsapp/webhook` and get the templates listed in Settings approved.
