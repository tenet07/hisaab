# Putting the shop app on a cloud server

One small server in Mumbai runs everything: the app, the Postgres database, HTTPS, and
nightly backups. Staff open it on their phones from anywhere. About an hour, done once.

## What it costs

| Item | Cost |
|---|---|
| AWS Lightsail, Mumbai, **2 GB plan** (2 vCPU, 60 GB disk) | about $12/month (~₹1,050) |
| Lightsail automatic snapshots (off-server copy, optional but recommended) | about $1–3/month |
| A domain, e.g. `solankielectricals.in` | ~₹600–900/year |
| HTTPS certificate | free (Caddy gets it from Let's Encrypt) |

The 1 GB plan ($7) also runs the app, but the first build can be slow; start with 2 GB.
Any Ubuntu server in India works the same way (DigitalOcean Bangalore, Hostinger, E2E).

## 1. Create the server (15 min, in the browser)

1. Sign in at lightsail.aws.amazon.com → **Create instance**.
2. Region **Mumbai (ap-south-1)**. Platform **Linux/Unix** → **OS Only → Ubuntu 24.04 LTS**.
3. Plan **$12 (2 GB)**. Name it `shop`. Create.
4. **Networking** tab → **Create static IP** → attach it to `shop`. Note the IP.
5. Same tab, **IPv4 Firewall** → add rule **HTTPS (443)**. (SSH 22 and HTTP 80 are already there.)
6. **Snapshots** tab → turn on **Automatic snapshots** (daily). This is the off-server copy.

## 2. Point the domain at it (5 min)

At the domain seller (GoDaddy, Hostinger…) add a DNS record:

| Type | Name | Value |
|---|---|---|
| A | `bills` | the static IP from step 1 |

The app will live at `https://bills.yourdomain.in`. DNS can take up to an hour.

## 3. Copy the app and start it (10 min)

On the Lightsail instance page, click **Connect using SSH** (a terminal opens in the browser).
Upload `shopos.zip` with the terminal's **⋮ → Upload file** button, then:

```bash
sudo apt-get update && sudo apt-get install -y unzip
unzip shopos.zip && cd shopos
sudo bash deploy/server-setup.sh bills.yourdomain.in
```

This installs Docker, writes `.env` with random passwords, builds the app and starts it.
At the end it prints a **setup code**. Write it down.

## 4. First run (5 min, on your phone)

Open `https://bills.yourdomain.in`. The setup page asks for the setup code, your shop
name, GSTIN, your name and a PIN. Then:

1. **Settings**: address, bank, UPI ID, bill prefix, terms, Tally ledger names.
2. **Staff**: add Accounts, Counter, Ramesh, Delivery 1 and 2 with their own PINs.
3. **Import**: products, customers (with opening balances), suppliers from Excel.
4. Make one test bill, print it, check it, then cancel it.

## Everyday running

Nothing. The app restarts itself if the server reboots. A backup runs every night at
23:30 and 30 days are kept on the server. Each week, the owner opens
**Settings → Backups → Download** and saves the latest file to Google Drive or a laptop.

## Safety built in

- HTTPS only; the app answers only for your domain.
- PIN login: 5 wrong PINs lock that person for 15 minutes; 20 tries per phone per 10 minutes.
  Setting a new PIN (Staff screen) unlocks at once.
- The setup page needs the setup code, so nobody else can claim a fresh server.
- Database is not reachable from the internet; only ports 80/443 (Caddy) are open.
- `.env` holds the passwords. Never send it to anyone or put it in WhatsApp.

## Commands for whoever looks after the server

Run these in the `shopos` folder over SSH.

| Job | Command |
|---|---|
| Is everything running? | `sudo docker compose ps` |
| What is the app doing? | `sudo docker compose logs -f --tail 100 app` |
| Install a new version | copy the new files over the folder (keep `.env` and `backups/`), then `sudo bash deploy/update.sh` (backs up first) |
| Backup right now | `sudo docker compose exec backup sh /backup.sh now` |
| List backups | `ls -lh backups/` |
| Restore a backup | `sudo bash deploy/restore.sh backups/shopos-2026-11-08_2330.dump` (asks you to type RESTORE; takes a safety backup first) |
| Owner locked out / forgot PIN | `sudo docker compose exec app bin/rails runner 'u=User.find_by!(name: "Gunjan"); u.update!(password: "4826"); puts "ok"'` then log in with 4826 and change it |
| Rails console | `sudo docker compose exec app bin/rails console` |
| Restart | `sudo docker compose restart app` |

## Restoring onto a brand-new server (server lost)

1. Steps 1–3 above with the same domain (point DNS at the new IP).
2. Upload your latest downloaded backup to the `shopos` folder.
3. `sudo bash deploy/restore.sh shopos-2026-11-08_2330.dump`

Or restore a Lightsail snapshot: **Snapshots → Create new instance**, attach the static IP.

## Later: more shops on one server

When a second wholesaler signs up, each shop gets its own database and its own address
(`gupta.yourapp.in`, `solanki.yourapp.in`) on the same server. Shop details, prefixes and
Tally ledgers are already stored in the database (not in the code), so this needs no
change to billing or GST logic. Nothing about it is needed for one shop.
