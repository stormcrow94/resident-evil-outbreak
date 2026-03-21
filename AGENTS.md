# AGENTS.md

## Cursor Cloud specific instructions

This is a **Docker-only** project (Resident Evil: Outbreak private game server). There is no language-specific package manager, no linter, and no automated test suite. All build and runtime logic lives inside the `Dockerfile` and Docker Compose files.

### Building

- **All-in-one** (data-center / single container): `sudo docker compose build` from the repo root.
- **Split** (MariaDB in separate container): `sudo docker compose -f docker-compose.split.yml build` from the repo root.
- Build args like `VARIANT` are set in the respective `docker-compose*.yml` files; no manual `--build-arg` is needed.
- The build takes ~5-6 minutes each variant (downloads OpenSSL 1.0.2q, Apache httpd 2.4.56, APR, clones upstream repos, compiles Java bioservers).
- Benign `libssl_conf.so` warnings appear during the OpenSSL 1.0.2 build step — these do not affect the image.

### Running

- Copy `.env.example` to `.env` and set `EXTERNAL_IP` to the host's LAN IP before starting.
- All-in-one: `sudo docker compose up -d`
- Split: `sudo docker compose -f docker-compose.split.yml up -d`
- The all-in-one container's healthcheck (`mysqladmin ping`) takes up to 120 s `start_period`; wait for `(healthy)` status.
- `patch.raw` FileNotFoundException in Java bioserver logs is benign (optional file, defaults to 0-byte patch).

### Cloud VM caveats

- Docker is **not** pre-installed; the VM environment snapshot handles installation of Docker CE, fuse-overlayfs, and iptables-legacy (required for nested Docker-in-Docker inside the Firecracker VM).
- `sudo` is required for all `docker` / `docker compose` commands since the `ubuntu` user is not in the `docker` group by default.
- Port 53 (DNS/dnsmasq) may conflict in some environments; it is optional for build verification — game servers work on ports 8200/8300/8590/8690 regardless.
