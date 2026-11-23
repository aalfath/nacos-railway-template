# Changelog

## 3.3.0 (2026-11-23)

First release of the template.

- Nacos 3.3.0 (`nacos/nacos-server:v3.3.0@sha256:bf18e41d09efd4e72edc46b010d42dca49f776421413cb2637be1fff0d6ef90f`), standalone mode with Railway MySQL.
- Admin `nacos` seeded on first boot from the generated `NACOS_ADMIN_PASSWORD`; auth secrets generated per deploy.
- Embedded Raft state on a volume at `/home/nacos/data`, Raft member pinned to `127.0.0.1` so redeploys (new container IP) keep persistent service instances.
- JVM sized for a 1 GB service.
