[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/nacos?utm_medium=integration&utm_source=button&utm_campaign=nacos)

# Nacos on Railway

One-click [Nacos](https://github.com/alibaba/nacos) (service discovery, configuration management and AI agent registry) for Railway.

- **Nacos 3.3.0**, official image `nacos/nacos-server:v3.3.0@sha256:bf18e41d09efd4e72edc46b010d42dca49f776421413cb2637be1fff0d6ef90f`, standalone mode.
- **Railway MySQL** as the config store. The schema bundled with the image is applied on every start (`CREATE TABLE IF NOT EXISTS`, under a MySQL lock).
- **Volume** on `/home/nacos/data` for Nacos's embedded Raft state (persistent service instances, locks).
- **Auth on, no default password.** The admin user `nacos` is created on first boot from the generated `NACOS_ADMIN_PASSWORD`, so nobody can claim the console before you. Token secret and server identity are generated per deploy.

## Services

| Service | What it does |
|---|---|
| `Nacos` | Built from this repo. Web console on the public domain (Railway `PORT`, 8080). Client API on `8848` and gRPC on `9848` over the private network. Health check `/v3/console/health/readiness`. |
| `MySQL` | Railway's MySQL. Stores configs, users, roles, namespaces and history. |

## Variables (Nacos service)

| Variable | Default | Purpose |
|---|---|---|
| `NACOS_ADMIN_PASSWORD` | `${{secret(24)}}` | Password of the `nacos` admin, set on first boot only. Change it later in the console. |
| `NACOS_AUTH_TOKEN` | `${{secret(64)}}` | Base64 key that signs login tokens. |
| `NACOS_AUTH_IDENTITY_KEY` / `NACOS_AUTH_IDENTITY_VALUE` | generated | Server identity header for server-to-server calls. |
| `MYSQL_SERVICE_*` | references to `MySQL` | Database connection. |
| `PORT` | `8080` | Console port behind the public domain. |

Optional: `NACOS_JVM_XMX` (default `256m`) and `NACOS_JVM_XMS`, `NACOS_JVM_XMN`, `NACOS_JVM_MMS` to resize the JVM when you give the service more RAM.

## Memory

Nacos needs about **600 MB** of RAM when idle (JVM plus five embedded RocksDB/Raft groups). Give the Nacos service **at least 1 GB**. It does not run in the 0.5 GB per-service limit of Railway's Free plan: it is killed for memory and restarted in a loop.

## Connecting clients

From another service in the same Railway project, point the Nacos client at `${{Nacos.RAILWAY_PRIVATE_DOMAIN}}:8848` (gRPC uses `9848`, port + 1000) with user `nacos` and the admin password, or with a user you create in the console. The public domain serves the console only.

## Updates

This template builds from this repo. When the pinned Nacos version is bumped on `main`, Railway shows deployers an "update available" notice and each deployer chooses when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first: breaking changes are listed first.
