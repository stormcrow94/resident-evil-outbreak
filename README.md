# Resident Evil / Biohazard: Outbreak — Docker server

Fork and extension of **[corbin-zip/bioserver-docker](https://github.com/corbin-zip/bioserver-docker)** (original author: **corbin-zip**). That project Dockerizes the DNAS replacement and bioserver stack for Biohazard Outbreak File 1 & 2.

This repository adds **public WAN / internet play** support via a `PUBLIC_IP` variable, `docker-compose.yml`, and deployment notes. Upstream’s README is preserved in spirit below; treat **WAN setup** as documented in this repo (`docker-compose.yml`, `PUBLIC_DEPLOY_NOTES.txt`, and `config/entrypoint.sh`).

## Upstream

- Original project: [https://github.com/corbin-zip/bioserver-docker](https://github.com/corbin-zip/bioserver-docker)

## What does it do?

It builds a Docker image that includes the DNAS replacement (DNASrep) and bioserver components, OpenSSL and Apache built from source for the DNAS server, dnsmasq for DNS, MariaDB, and the Java game servers. Image size is roughly on the order of ~2.25GB.

## Quick start (Docker Compose, public IP)

1. Edit `docker-compose.yml` and set `PUBLIC_IP` to your real **WAN** (public) IP—the same address players will use for DNS.  
   **Documentation examples** use `203.0.113.42` (RFC 5737 TEST-NET-3, documentation-only — not a real routable address). Replace any example with your own IP.
2. From this directory:

```bash
docker compose build
docker compose up -d
docker logs -f bioserver
```

3. On the router, forward the ports listed in `PUBLIC_DEPLOY_NOTES.txt` to the host running Docker.
4. Players (e.g. PCSX2): set **primary DNS** to that **same** public IP (again, only `203.0.113.42` in docs as a stand-in example).

See `PUBLIC_DEPLOY_NOTES.txt` for verification commands and firewall details.

## Legacy: manual Docker (from upstream)

This requires Docker and Git. You can still build and run without Compose:

```
git clone https://github.com/stormcrow94/resident-evil-outbreak.git
cd resident-evil-outbreak
docker build -t "bioserver-docker" .
docker container create --name bioserver bioserver-docker:latest
docker container start bioserver
```

For the container’s IP (local/LAN DNS to the container):

`docker ps -q | xargs docker inspect --format "{{range .NetworkSettings.Networks}}{{print .IPAddress}} {{end}}{{.Name}}"`

(Non-trivial one-liner; [Super User discussion](https://superuser.com/questions/1167922/get-list-of-docker-ip-containers).)

## Limitations (upstream)

Upstream noted that **remote play was not fully integrated** in the original README; **this fork** addresses that with `PUBLIC_IP`, published ports, and dnsmasq pointing DNAS names at your WAN address. Remaining caveats from upstream (database import on first run, etc.) may still apply—see upstream issues and `PUBLIC_DEPLOY_NOTES.txt`.

## License / attribution

Respect the licenses of upstream **corbin-zip/bioserver-docker** and any vendored or downloaded components (DNASrep, bioserver, Apache, OpenSSL, etc.).
