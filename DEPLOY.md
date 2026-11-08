# Putting the shop app on a cloud server

One small server in India runs the app and HTTPS for one shop. The shop's data is one
SQLite database file, copied to Cloudflare R2 within a second of every change and also
saved on the server every night. About an hour to set up, done once.

Who uses it: **the shop's desktop** (owner, accounts, counter) and **the delivery person's
phone**. Both install it as an app from the browser: no app store, nothing to pay for.

## What it costs (per year)

| Item | Choice | ₹ / year |
|---|---|---|
| Server, 1 GB RAM, India | Vultr Mumbai ($5/month) or DigitalOcean Bangalore ($6/month) | ~5,300 – 6,300 |
| Off-server copy | Cloudflare R2 free tier (10 GB; the shop needs well under 1 GB) | 0 |
| HTTPS certificate | Caddy + Let's Encrypt | 0 |
| Code, builds, app image | GitHub (repo, Actions, container registry) | 0 |
| Web address | own `.in` domain (~₹700–900/yr) **or** free `yourshop.duckdns.org` | 0 – 900 |
| WhatsApp | tap-to-send links from the app (no API, no broadcasts) | 0 |
| **Total** | | **~5,300 – 7,200** |

Dollar prices at about ₹88/$. Cheapest: Vultr + DuckDNS ≈ ₹5,300/year.

## 1. Create the server (10 min, in the browser)

**Vultr** (vultr.com → Deploy → Cloud Compute, Shared CPU) or **DigitalOcean**
(digitalocean.com → Create → Droplet). Either works the same way.

1. Location **Mumbai** (Vultr) or **Bangalore** (DigitalOcean).
2. Image **Ubuntu 24.04 LTS**. Plan: **1 GB RAM** (the $5/$6 one).
3. Authentication: SSH key if you have one, otherwise a root password (save it).
4. Create. Note the server's **IPv4 address**.
5. Firewall: allow ports **22, 80, 443** only (DigitalOcean: Networking → Firewalls;
   Vultr: Products → Firewall). Ubuntu's own firewall can stay off.

## 2. Give it a web address (5 min)

**Own domain** (`solankielectricals.in`): at the domain seller, add a DNS record
`A  bills  →  <server IP>`. The app will be at `https://bills.solankielectricals.in`.

**Free instead:** sign in at duckdns.org with Google, create `solanki-shop`, put the server IP
in "current ip", update. The app will be at `https://solanki-shop.duckdns.org`.

DNS can take up to an hour to work everywhere.

## 3. Cloudflare R2 for the off-server copy (10 min)

1. Sign up free at dash.cloudflare.com → **R2 Object Storage** → enable (a card is asked
   for; the free tier is not charged).
2. **Create bucket** → name `shop-backups`, location **Asia-Pacific**.
3. R2 → **Manage API tokens** → **Create API token** → permission **Object Read & Write**,
   only bucket `shop-backups`. Copy the **Access Key ID**, **Secret Access Key** and the
   **endpoint** (`https://<account-id>.r2.cloudflarestorage.com`). They are shown once.

You'll paste these into the server's `.env` in step 4.

## 4. Install on the server (10 min)

Log in: `ssh root@<server IP>` (Windows: PowerShell; or the provider's web console).

```bash
apt-get update && apt-get install -y git
git clone https://github.com/tenet07/hisaab.git shopos && cd shopos
bash deploy/server-setup.sh bills.solankielectricals.in
```

This installs Docker, writes `.env` with random secrets, downloads the app (built by
GitHub, see `.github/workflows/image.yml`) and starts it with HTTPS. It prints a
**setup code**: write it down.

Now turn on the R2 copy:

```bash
nano .env
#   fill R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY (R2_BUCKET=shop-backups)
#   remove the # in front of COMPOSE_PROFILES=r2, save (Ctrl+O, Enter, Ctrl+X)
docker compose up -d
docker compose logs --tail 20 litestream     # should say "replicating" with no errors
```

If `server-setup.sh` says "no ready-made image": the GitHub image is private. Either make
it public (GitHub → your profile → Packages → hisaab → Package settings → Change
visibility → Public), or leave it: the server builds the app itself (about 10 minutes).

## 5. First run (5 min, at the shop's desktop)

Open the web address. The setup page asks for the setup code, shop name, GSTIN, your
name and a PIN. Then:

1. **Settings**: address, bank, UPI ID, bill prefix, terms, Tally ledger names.
2. **Staff**: add the delivery person (role Delivery) with their own PIN; add Accounts or
   Counter logins only if more than one person uses the desktop.
3. **Import**: products, customers (with opening balances) and suppliers from Excel.
4. Make one test bill, print it, check it, then cancel it.

## 6. Install the two apps

**Shop desktop** (Chrome or Edge): open the web address, log in, click **Install app** at
the bottom of the left menu (or the install icon at the right end of the address bar).
It gets its own window and a desktop/taskbar icon.

**Delivery phone** (Android, Chrome): open the web address, log in as the delivery person,
tap the round name button at the top right → **Install app**. An icon appears on the home
screen and opens straight to today's deliveries. iPhone: Safari → Share → **Add to Home Screen**.

Both need internet. Without signal the app shows "No internet" and nothing typed so far is
saved; the delivery person retries when the signal is back.

## Everyday running

Nothing. Everything restarts itself if the server reboots. Every change is in R2 within a
second; a full copy is also saved on the server every night at 23:30 and kept 30 days.
Once a month, the owner can also download one from **Settings → Backups**.

## Safety built in

- HTTPS only; the app answers only for its own web address.
- PIN login: 5 wrong PINs lock that person for 15 minutes; 20 tries per phone per 10 minutes.
  Setting a new PIN unlocks at once.
- The first-run page needs the setup code, so nobody else can claim a fresh server.
- `.env` holds the secrets and R2 keys. Never send it to anyone or put it on WhatsApp.

## Commands for whoever looks after the server

Run these in the `shopos` folder, logged in as root.

| Job | Command |
|---|---|
| Is everything running? | `docker compose ps` |
| What is the app doing? | `docker compose logs -f --tail 100 app` |
| Install the latest version | `bash deploy/update.sh` (backs up first, pulls the new image, restarts) |
| Copy right now | `docker compose exec backup sh /backup.sh now` |
| List nightly copies | `ls -lh backups/` |
| Restore a nightly or downloaded copy | `bash deploy/restore.sh backups/shopos-2026-11-08_2330.sqlite3` |
| Restore from R2 (latest) | `bash deploy/restore.sh r2` |
| Restore from R2 as it was at a moment | `bash deploy/restore.sh r2 "2026-11-08 14:05"` |
| Owner forgot PIN / locked out | `docker compose exec app bin/rails runner 'User.find_by!(name: "Gunjan").update!(password: "4826")'` then log in with 4826 and change it |
| Rails console | `docker compose exec app bin/rails console` |

Every restore asks you to type RESTORE and saves the current state first.

## Server lost

1. Steps 1, 2 and 4 on a new server with the same web address (point DNS at the new IP),
   and the same R2 keys in `.env`.
2. `bash deploy/restore.sh r2`: the shop is back as it was a second before the old server died.

## Growing later

- **More users or a busier shop:** move to the 2 GB plan in the provider's dashboard (a few
  minutes, data stays).
- **Postgres:** set `DATABASE_URL=postgres://…` and the app uses Postgres instead; nothing
  else changes (the test suite runs on both on every push).
- **Selling to other wholesalers:** each shop gets its own database file (`SHOP_DB`) and its
  own address. Shop details, bill prefixes and Tally ledgers already live in each shop's
  database, not in the code. One 1–2 GB server holds many shops, so hosting stays at a
  few hundred rupees per shop per year.
