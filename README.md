# Shop OS

Billing, stock, collections, replacements and Tally export for a
lighting and electrical shop (retail + wholesale, six markets).

## Contents

1. [Set up a development machine](#set-up-a-development-machine)
2. [Run the tests](#run-the-tests)
3. [Try it with Postgres locally (optional)](#try-it-with-postgres-locally-optional)
4. [Run a dev/staging server](#run-a-devstaging-server)
5. [Production](#production) and [DEPLOY.md](DEPLOY.md)

## Set up a development machine

Works on macOS, Linux and Windows (WSL2 with Ubuntu). About 15 minutes.

### 1. Install the tools

| Tool | Version | Check |
| --- | --- | --- |
| Git | any | `git --version` |
| Ruby | 3.3.6 (see `.ruby-version`) | `ruby -v` |
| SQLite | 3.x | `sqlite3 --version` |
| Build tools + libyaml | for compiling gems | |

**macOS**

```bash
xcode-select --install
brew install rbenv ruby-build libyaml sqlite
rbenv init            # follow the printed line, then open a new terminal
rbenv install 3.3.6
```

**Ubuntu / WSL2**

```bash
sudo apt-get update
sudo apt-get install -y git curl build-essential libssl-dev libyaml-dev zlib1g-dev libsqlite3-dev sqlite3 libpq-dev
curl -fsSL https://rbenv.org/install.sh | bash   # or: sudo apt-get install rbenv ruby-build
# add rbenv to your shell as the installer says, open a new terminal, then:
rbenv install 3.3.6
```

(`mise` or `asdf` work too: `mise use ruby@3.3.6`.)

### 2. Get the code and install gems

```bash
git clone git@github.com:<owner>/<repo>.git shopos
cd shopos
ruby -v                  # must say 3.3.6 (rbenv picks it from .ruby-version)
gem install bundler
bundle install
```

The `pg` gem is installed too (used on the server). It ships prebuilt for common
platforms; if it fails to build, install `libpq-dev` (Ubuntu) or `brew install libpq`
(macOS) and run `bundle install` again.

### 3. Create the database with demo data

```bash
bin/rails db:prepare
```

This makes `storage/development.sqlite3` and loads a demo shop: Solanki Electricals,
6 markets, 7 customers, 8 products, 3 suppliers, a few bills, a payment and a replacement.
Start again from scratch at any time with `bin/rails db:reset`.

### 4. Start the app

```bash
bin/rails server            # http://localhost:3000
```

To open it from your phone on the same Wi-Fi: `bin/rails server -b 0.0.0.0`, then visit
`http://<your-computer's-IP>:3000`.

Demo logins, all with PIN `1234`:

| Login | Role | Sees |
| --- | --- | --- |
| Owner | owner | everything, Settings, Staff, Backups |
| Accounts | accounts | billing, money, suppliers, Tally, import |
| Counter | counter | billing at the counter |
| Ramesh | salesman | phone visit screen: dues, orders, payments, replacements |
| Delivery 1, Delivery 2 | delivery | only their own delivery run |

### 5. Shop details

Shop name, GSTIN, state, address, bill prefixes, bank and UPI ID, bill terms and Tally
ledger names are set in the app under **Settings** (owner only), not in code or
environment variables. The GST state decides CGST+SGST vs IGST: a customer whose GSTIN
starts with another state code is billed IGST.

### Starting with an empty shop instead of the demo

```bash
bin/rails db:drop db:create db:schema:load   # no seeds
bin/rails server
```

The first visit shows the setup page (shop name, GSTIN, owner and PIN). Then add staff
under **Staff** and import products, customers and suppliers from Excel under **Import**
(see [Going live](#going-live)).

## Run the tests

```bash
bin/rails test            # 90 tests, about 3 seconds
```

Plain-Ruby GST, stock and ledger rules are in `test/lib`; money flows through `Books` in
`test/services`; screens and permissions in `test/integration`. GitHub Actions runs the
suite on every push, on both SQLite and Postgres (`.github/workflows/test.yml`).

## Try it with Postgres locally (optional)

The server uses Postgres. To run the tests against it on your machine:

```bash
docker run -d --name shopos-pg -p 5432:5432 -e POSTGRES_PASSWORD=dev postgres:16-alpine
export DATABASE_URL=postgres://postgres:dev@localhost:5432/shopos_test
RAILS_ENV=test bin/rails db:create db:schema:load
bin/rails test
unset DATABASE_URL
```

## Run a dev/staging server

A staging server is the same setup as production (see [DEPLOY.md](DEPLOY.md)) on its own
subdomain, e.g. `dev.yourshop.in`, so changes can be tried on phones before the shop uses them.

1. Create a small Lightsail instance (the $7 1 GB plan is enough for staging) and point
   `dev.yourshop.in` at its static IP.
2. On the server:

   ```bash
   sudo apt-get update && sudo apt-get install -y git
   git clone https://github.com/<owner>/<repo>.git shopos && cd shopos
   sudo bash deploy/server-setup.sh dev.yourshop.in
   ```

   For a private repo, create a read-only **deploy key** (GitHub → repo → Settings →
   Deploy keys) on the server with `ssh-keygen -t ed25519`, add the `.pub` there, and
   clone with `git@github.com:<owner>/<repo>.git`.
3. Either open `https://dev.yourshop.in` and do first-run setup with the printed setup
   code, or load the demo shop instead:

   ```bash
   sudo docker compose exec -e DEMO_DATA=1 app bin/rails db:seed
   ```

   (Demo logins as above, PIN `1234`. Never load demo data on the real shop's server.)
4. Deploy new code later:

   ```bash
   git pull && sudo bash deploy/update.sh
   ```

## How it stays correct

- `lib/shop.rb`: GST maths, stock buckets, ledger rules, warranty and Tally XML.
  Plain Ruby with its own tests (`test/lib`).
- `app/services/books.rb`: the **only** code that writes stock movements and
  ledger entries. Every action posts in one transaction, all or nothing.
- Stock and balances are never typed in; they are sums of append-only rows.
  Mistakes are fixed by reversing entries (cancel bill, count adjustment).
- Every entry records who made it.

## Design

Phone-first: a bottom tab bar on phones (5 tabs per role, the rest under
"More"), a sidebar on desktop, 48px touch targets, dark mode, and WCAG AA
contrast. The bill form is a searchable item picker with a live total; the
salesman can collect a payment on the visit screen in two taps; delivery
hand-over is "type the code, tap Delivered". See `UX_NOTES.md` for the
design system and the reasoning behind each change.

## Screens

- **Today** (owner/accounts): sales, collections by mode, dues by market,
  over-limit customers, low stock, claims open with brands.
- **New bill**: picks wholesale or retail price by customer, adds GST,
  flags e-way bills above ₹50,000, then **Send on WhatsApp**.
- **Customer**: ledger with running balance, unpaid bills (oldest settled
  first), ageing, printable statement, WhatsApp reminder.
- **Salesman visit** (phone): amount due, oldest bill, last bills, buttons
  for order, payment, replacement, reminder.
- **Stock**: sellable / awaiting claim / with brand / written off; goods
  received; physical count with reason.
- **Replacements and claims**: warranty checked from sale date; out of
  warranty needs owner. Claims batch a brand's defective pieces, then settle
  as new piece, credit note, or rejected (owner only).
- **Dispatch** (office): each wholesale bill becomes a delivery on its
  market's delivery day, pre-assigned to that market's delivery person.
  Reassign, move dates, reschedule failed stops. Untick "Deliver" on the
  bill for goods the customer takes away.
- **My run** (delivery staff, phone): stops by market → load check →
  hand over with the customer's 4-digit code (sent in their WhatsApp bill,
  never shown to staff) or a photo → optional payment on delivery.
  Short items need a reason; the customer gets a GST credit note
  automatically; good pieces go back on the shelf, damaged ones are
  written off. "Couldn't deliver" keeps the bill and flags it for rescheduling.
- **End of day**: per delivery person, stops done, cash to hand in, and
  every item that should be back in the shop.
- **Stock page** shows what to expect on the shelf: sellable plus billed
  goods not yet delivered.
- **Suppliers** (office): each distributor with the brands you buy from
  them and credit days. **Purchase bills** are copied from the supplier's
  bill (rates before GST); the app computes GST and refuses to save if its
  total differs from the printed total by more than ₹1, or if that bill
  number was already entered. Saving adds stock and what you owe together.
  Unpaid items (opening balance first, then bills) with due dates.
  **Pay supplier** (owner/accounts) by UPI, cheque or cash.
- **Brand credit notes**: on a claim, pieces marked "credit note" show
  their value at your last purchase cost; recording the brand's credit note
  reduces what you owe that supplier. The Today screen lists claims still
  waiting for one.
- **Tally**: date range → XML of sales, credit notes, receipts, purchases, supplier payments
  and brand claim credits (as Journal vouchers to `Warranty Claims Received`;
  ask your CA if they prefer debit notes). Import into a **copy**
  of the company first; ledger names must match.

## Going live

1. **Owner** opens the app, creates their login, then adds each staff member
   under **Staff** with their own PIN (4–6 digits; easy ones like 1234 are
   refused outside the demo). Everyone can change their PIN by tapping their
   name. Turn off access when someone leaves; their entries stay.
2. **Import** (owner/accounts): download the template for suppliers, products
   and customers, fill it in Excel, upload. Every row is checked and shown
   before saving; one bad row blocks the save so nothing half-imports.
   Common header spellings (MRP, GST %, Mobile, Area, Outstanding…) are
   understood; anything else is refused rather than silently ignored.
   Re-importing updates existing items; opening stock and balances are only
   set once.
3. Count stock on the day you import opening stock, and confirm each
   customer's opening balance with them.

## WhatsApp

v1 uses `wa.me` links: one tap opens WhatsApp with the bill, receipt or
reminder typed out, and staff press send. No API account needed. Automatic
sending through the WhatsApp Business API is the next step (see the plan).

## Not built yet

WhatsApp order parsing, automatic
WhatsApp sends, PDF bills, purchase returns,
offline mode for the salesman app, e-way bill generation.

## Production

Runs on one cloud server with `docker compose`: the app, Postgres 16, Caddy (automatic
HTTPS) and a nightly `pg_dump` backup kept 30 days. Step-by-step for AWS Lightsail Mumbai,
costs and the everyday commands are in **[DEPLOY.md](DEPLOY.md)**.

- `Dockerfile`, `docker-compose.yml`, `deploy/` (Caddyfile, server-setup, update, backup, restore).
- Development and tests use SQLite; production uses `DATABASE_URL` (Postgres). The test suite
  passes on both: `DATABASE_URL=postgres://… bin/rails test`.
- Times and dates are Indian time (`Asia/Kolkata`) whatever the server clock says.
- Login: 5 wrong PINs lock a person for 15 minutes; 20 tries per IP per 10 minutes; a new
  PIN unlocks. First-run setup needs `SETUP_CODE` from `.env`.
- Owner downloads backups from **Settings → Backups** for an off-server copy.
