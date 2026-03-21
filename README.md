# Resident Evil / Biohazard: Outbreak — Docker server

Private server stack for **Outbreak File #1** and **File #2**: DNAS (HTTPS + PHP), dnsmasq, MariaDB, and the Java bioservers from [corbin-ch/bioserver](https://github.com/corbin-ch/bioserver) and [corbin-ch/DNASrep](https://github.com/corbin-ch/DNASrep). This repo pins Debian/OpenSSL/Apache/MySQL connector versions, adds **persistent MariaDB data**, optional **split-database** Compose, and **JDBC `db_host` / `db_port`** in `config.properties` so the Java servers can use a remote MariaDB container.

Upstream references: [Biohazard: Outbreak Server Setup (corbin.zip)](https://www.corbin.zip/outbreak-server/), [bioserver-docker](https://github.com/corbin-zip/bioserver-docker).

## Requirements

- Docker with Compose v2
- **EXTERNAL_IP**: the LAN IP of the machine running Docker, as used by your PS2 or PCSX2 (same subnet)

## Quick start (all-in-one)

1. Copy [`.env.example`](.env.example) to `.env` and set `EXTERNAL_IP` (and optionally `MYSQL_PASSWORD`).

2. Start:

   ```bash
   docker compose up -d --build
   ```

3. Point the client’s **DNS** to `EXTERNAL_IP` (not a hostname). For PCSX2, use a DEV9 plugin that supports custom DNS (e.g. CLR_DEV9); see [obsrv-pack](https://github.com/adrianopteodoro/obsrv-pack) notes and community wikis.

Published ports: **53/tcp+udp** (DNS), **80**, **443** (DNAS), **8200**, **8300**, **8590**, **8690** (game traffic).

## Split stack (MariaDB in its own container)

Better for backups and DB upgrades. Uses the same image built with `VARIANT=split` (no `mariadb-server` in the app image).

```bash
# .env must include MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD, EXTERNAL_IP
docker compose -f docker-compose.split.yml up -d --build
```

The app service waits for MariaDB on hostname `mariadb`, initializes schemas via [`docker/mariadb/init/01-databases.sh`](docker/mariadb/init/01-databases.sh), and grants `bioserver`@`%`.

## Data persistence and first-boot behavior

### All-in-one

- Volume **`mariadb_data`** is mounted at **`/var/lib/mysql`**. User accounts and game data survive **image rebuilds** and **container recreation**.
- First time the data directory is empty, the entrypoint imports [`bioserv1/database/bioserver.sql`](https://github.com/corbin-ch/bioserver/blob/master/bioserv1/database/bioserver.sql) and [`bioserv2/database/bioserver.sql`](https://github.com/corbin-ch/bioserver/blob/master/bioserv2/database/bioserver.sql) (with your `MYSQL_PASSWORD`).
- Markers on that volume prevent double-import and duplicate Apache SSL snippets:
  - `/var/lib/mysql/.outbreak-db-init`
  - `/var/lib/mysql/.outbreak-httpd-configured`

### Split

- **`mariadb_split`** holds the database; **`outbreak_app_state`** holds Apache tuning markers for the app container.

### Backup / restore (example)

**All-in-one** — Compose project name is [`outbreak-server`](docker-compose.yml), so the DB volume is typically `outbreak-server_mariadb_data`. Confirm with `docker volume ls`.

```bash
docker run --rm -v outbreak-server_mariadb_data:/var/lib/mysql -v "%CD%":/backup alpine \
  tar czf /backup/mariadb_data_backup.tgz -C /var/lib/mysql .
```

Restore into a fresh volume:

```bash
docker run --rm -v outbreak-server_mariadb_data:/var/lib/mysql -v "%CD%":/backup alpine \
  sh -c "cd /var/lib/mysql && tar xzf /backup/mariadb_data_backup.tgz"
```

On Linux, replace `%CD%` with `"$(pwd)"`.

## Build arguments (image)

| ARG | Default | Purpose |
|-----|---------|---------|
| `DEBIAN_VERSION` | `bullseye-slim` | Base image |
| `VARIANT` | `allinone` | `allinone` = MariaDB in image; `split` = app only |
| `OPENSSL_TARBALL_URL` | OpenSSL 1.0.2q | Weak ciphers for PS2 DNAS |
| `HTTPD_TARBALL_URL` | httpd 2.4.56 (archive) | Apache source |
| `APR_TARBALL_URL` / `APR_UTIL_TARBALL_URL` | APR 1.7.2 / APR-util 1.6.3 | Bundled with httpd build |
| `MYSQL_CONNECTOR_DEB_URL` | mysql-connector-j 8.0.32 (Debian 11) | JDBC driver |

If a download URL 404s, point the ARG at a current mirror (see [Apache downloads](https://httpd.apache.org/download.cgi), [OpenSSL](https://www.openssl.org/source/)).

## WSL2 (Docker Desktop) vs Linux

- **UDP port 53** on Windows/WSL2 often conflicts with the host resolver or requires admin; you may still validate **HTTPS (443)** and **game ports** before moving to a Linux host for full DNS.
- On a **Linux** host, publishing **53/udp** is the reliable path for real hardware PS2 clients.

## License

Bioserver and related code are under **AGPL-3.0** (see upstream [bioserver](https://github.com/corbin-ch/bioserver)). Patches in [`patches/`](patches/) are derivative and should be treated under the same terms where applicable.
