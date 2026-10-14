# Uptime Kuma status page: IP tags and dense dark theme

Show each monitor's IP address on an [Uptime Kuma](https://github.com/louislam/uptime-kuma) status page, with a compact dark theme built for wall displays.

Uptime Kuma doesn't put hostnames on status pages by itself. A small SQL script copies each monitor's **Hostname** into a tag named `IP`, cron keeps those tags current, and custom CSS styles them on the page.

```
 Monitor "Office Printer"        Tag "IP"               Status page card
 Hostname: 192.0.2.10    ──►   value: 192.0.2.10    ──►   Office Printer
                         SQL                  CSS         IP:192.0.2.10
                       (cron)                             ▮▮▮▮▮▮▮▮▮▮▮▮
```

---

## Repository contents

| File | Purpose |
|---|---|
| `add-ip-tags.sql` | Creates and updates the `IP` tags. For MariaDB (embedded or external). |
| `add-ip-tags-sqlite.sql` | Same, for SQLite installs. |
| `uptime-kuma-status-dense-dark.css` | Custom CSS theme for the status page. |

## Requirements

- Uptime Kuma running in Docker. Steps are tested on Kuma 2.x with embedded MariaDB; SQLite and external MariaDB are covered under [Other database types](#other-database-types).
- Shell access to the Docker host, with permission to run `docker` and edit root's crontab.
- A modern browser for the status page. The theme uses `:has()` and `color-mix()`.

## Assumptions in this guide

Adjust these to match your install.

| Setting | Value used here |
|---|---|
| Install folder (compose file and these files) | `/opt/uptime-kuma` |
| Data volume | `./data:/app/data` |
| Container name | `uptime-kuma` |
| Database | Embedded MariaDB, database `kuma` |
| Socket (inside container) | `/app/data/run/mariadb.sock` |
| IP tag color | `#6B7280` (gray) |

Example layout on the host:

```
/opt/uptime-kuma/
├── docker-compose.yml
├── data/                               Kuma data, mounted at /app/data
│   ├── db-config.json                  Which database Kuma uses
│   └── mariadb/                        Embedded MariaDB files
├── data.bak-YYYY-MM-DD/                Backups (see "Back up and restore")
├── add-ip-tags.sql
├── add-ip-tags-sqlite.sql
└── uptime-kuma-status-dense-dark.css
```

> `/app` only exists inside the container. Any command that uses it goes through `docker exec`.

> **Security note:** if your status page is public, these tags show your internal IP addresses to anyone who visits it. Consider putting the page behind authentication or a reverse-proxy access control, or only tagging monitors you're comfortable exposing.

---

## Quick reference

**Tag new monitors now** (no restart needed):
```
cd /opt/uptime-kuma
docker exec -i uptime-kuma mariadb -S /app/data/run/mariadb.sock -u root kuma < add-ip-tags.sql
```

**Back up:**
```
cd /opt/uptime-kuma
docker stop uptime-kuma && cp -a data data.bak-$(date +%F) && docker start uptime-kuma
```

**Check the cron job:**
```
sudo crontab -l
```

---

## Day-to-day

**Adding a monitor:** nothing to do. Cron tags it within 15 minutes. To see it right away, run the tag command from the quick reference.

**Changing a monitor's IP:** nothing to do. The next cron run updates its tag.

**Adding other tags:** use any color except `#6B7280`. That gray is how the CSS recognizes the `IP` tag.

**Editing the theme:** change `uptime-kuma-status-dense-dark.css`, then paste the whole file into the status page's **Custom CSS** and click **Save**. Keeping this file as the source copy means the theme can always be restored.

---

## Back up and restore

Stop Kuma before copying, so the database files are consistent. Do this before any manual database change.

### Back up

```
cd /opt/uptime-kuma
docker stop uptime-kuma
cp -a data data.bak-$(date +%F)
docker start uptime-kuma
docker logs --tail 20 uptime-kuma
```

Kuma is back when the log shows it listening on port `3001`.

### Restore

```
cd /opt/uptime-kuma
docker stop uptime-kuma
mv data data.broken-$(date +%F)
cp -a data.bak-YYYY-MM-DD data
docker start uptime-kuma
```

Swap `YYYY-MM-DD` for the backup you want. The broken copy is kept, not deleted, in case you need anything from it.

---

## The tag script: `add-ip-tags.sql`

Each run does four things:

1. Creates the `IP` tag if it doesn't exist yet.
2. Tags every monitor that has a hostname but no `IP` tag.
3. Updates tags whose IP no longer matches the monitor's hostname.
4. Prints every tagged monitor with its IP.

It skips monitors without a hostname (HTTP checks, groups), changes nothing it doesn't need to, and is safe to run as often as you like while Kuma is running.

### Test the connection first

```
docker exec uptime-kuma mariadb -S /app/data/run/mariadb.sock -u root kuma -e "SELECT COUNT(*) FROM monitor;"
```

A monitor count means you're connected.

### Run it

```
cd /opt/uptime-kuma
docker exec -i uptime-kuma mariadb -S /app/data/run/mariadb.sock -u root kuma < add-ip-tags.sql
```

The `-i` is what passes the file into the container. Without it, the command runs but does nothing.

---

## Automatic updates with cron

The script runs every 15 minutes from root's crontab.

### Set up

1. Run `sudo crontab -e`.
2. Add this line:
   ```
   */15 * * * * docker exec -i uptime-kuma mariadb -S /app/data/run/mariadb.sock -u root kuma < /opt/uptime-kuma/add-ip-tags.sql > /dev/null 2>&1
   ```
3. Save and exit.

### Change how often it runs

Replace `*/15 * * * *` at the start of the line:

| Every | Use |
|---|---|
| 5 minutes | `*/5 * * * *` |
| 15 minutes | `*/15 * * * *` |
| Hour | `0 * * * *` |
| Day at 2:00 AM | `0 2 * * *` |

### Turn it off

Run `sudo crontab -e` and delete the line.

---

## The status page theme: `uptime-kuma-status-dense-dark.css`

### Apply it

1. Open the status page and click **Edit Status Page**.
2. Turn on **Show Tags**.
3. Paste the contents of `uptime-kuma-status-dense-dark.css` into **Custom CSS**.
4. Click **Save**.

### What it does

- **Dense grid.** Monitors sit in a tight grid of cards, with larger text on 4K screens.
- **Problems stand out.** Down monitors get a red tint and a slow pulse, and move to the front of their group. Pending monitors come right after.
- **Status banner.** "All Systems Operational" is a full-width banner that turns red, amber or blue when something is wrong.
- **IP tag.** Shown as a gray outline, always first on the card. Other tags keep their own colors.
- **Uptime badge.** Sits in its own strip under the heartbeat bar, so it never covers it.

The section numbers in the file's comments match these features, so each one is easy to find and tweak. Most sizes and colors are variables at the top of the file.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `ERROR 1698 (28000): Access denied for user 'root'@'localhost'` | Remove `-u node` from `docker exec`. The command must run as the container's default user. |
| `mariadb: not found` | Use `mysql` in place of `mariadb`. |
| Script runs but no tags appear | Check that `-i` is on `docker exec`. |
| Cron job never runs | Cron may not find `docker`. Run `which docker` and use the full path (usually `/usr/bin/docker`) in the cron line. |
| IPs not showing on the status page | Turn on **Show Tags** in **Edit Status Page** and click **Save**. |
| IP tag shows as a colored pill, or isn't first | The tag's color was changed. Set it back to `#6B7280`, or update the color in section 13 of the CSS. |
| Another tag moved to the front | It shares the IP tag's gray. Give it a different color. |
| `cd /app` fails on the host | Expected. `/app` is inside the container. On the host it's `/opt/uptime-kuma/data`. |

---

## Other database types

The steps above are for embedded MariaDB. To check what an install uses:

```
cat /opt/uptime-kuma/data/db-config.json
```

| `type` in the file | Database | Use |
|---|---|---|
| `embedded-mariadb` | MariaDB inside the Kuma container | Everything above |
| `mariadb` | MariaDB on its own server or container | [External MariaDB](#external-mariadb) |
| `sqlite`, or no file (Kuma 1.x) | SQLite | [SQLite](#sqlite) |

Backups and the CSS work the same on all of them.

### External MariaDB

Same script, `add-ip-tags.sql`. The connection details (hostname, port, username, password, database name) are in `db-config.json`.

**Database in the same compose file:**
```
cd /opt/uptime-kuma
docker compose ps
docker compose exec -T <db-service> mariadb -u <username> -p<password> <dbName> < add-ip-tags.sql
```
`docker compose ps` shows the database's service name. Note there's no space after `-p`.

**Database on another server:**
```
mariadb -h <hostname> -P <port> -u <username> -p<password> <dbName> < /opt/uptime-kuma/add-ip-tags.sql
```

For cron, use either command with full paths.

The `data` folder backup does **not** include an external database. Back it up separately:
```
mariadb-dump -h <hostname> -P <port> -u <username> -p<password> <dbName> > kuma-$(date +%F).sql
```

### SQLite

Use `add-ip-tags-sqlite.sql`. SQLite can't run the `UPDATE ... JOIN` in the MariaDB script, so this version does the same four things in SQLite-friendly syntax.

The database is `/opt/uptime-kuma/data/kuma.db`, sometimes with `kuma.db-wal` and `kuma.db-shm` beside it. The `data` folder backup covers all three.

The Kuma container doesn't include `sqlite3`, so run it from the host. Install it if needed (use your local package mirror in an offline environment):
```
sudo apt install sqlite3
```

**Test:**
```
sqlite3 /opt/uptime-kuma/data/kuma.db "SELECT COUNT(*) FROM monitor;"
```

**Run:**
```
sqlite3 /opt/uptime-kuma/data/kuma.db < /opt/uptime-kuma/add-ip-tags-sqlite.sql
```

**Cron:**
```
*/15 * * * * sqlite3 /opt/uptime-kuma/data/kuma.db < /opt/uptime-kuma/add-ip-tags-sqlite.sql > /dev/null 2>&1
```

Kuma can keep running. If you get `database is locked`, run it again.

---

## Credits

The CSS theme builds on [Uptime Kuma Status Page Dark Mode High Density Tweaks](https://gist.github.com/brooksvb/78a54355151a18477e33c224177dc5fa) by [@brooksvb](https://github.com/brooksvb).

## License

MIT License - feel free to use this
