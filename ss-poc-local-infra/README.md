# st-poc-local-infra

Local Docker infrastructure for the **st-poc** .NET microservices POC.

This stack is for local development only. It gives service repos shared dependencies and developer tools without adding Kubernetes, cloud deployment files, or production assumptions.

## Included Services

| Profile | Services |
| --- | --- |
| `edge` | Traefik reverse proxy and local load balancer |
| `core` | Postgres, MongoDB, Redis, Garage, Garage Web UI |
| `broker` | RabbitMQ with management UI |
| `mail` | Mailpit |
| `obs` | Seq, Jaeger, Prometheus, Grafana |
| `secrets` | Vault |
| `tools` | Portainer |

All services use the shared Docker network `st_poc_shared`. Persistent services use named Docker volumes with the `st_poc_` prefix.

## Resource Limits

The stack includes explicit local CPU and memory caps so one service does not consume the whole Docker Desktop VM. These are development limits, not sizing guidance for production.

| Service | CPU limit | Memory limit | Memory reservation |
| --- | ---: | ---: | ---: |
| Traefik | `0.50` | `512m` | `128m` |
| Postgres | `0.75` | `768m` | `256m` |
| MongoDB | `1.00` | `1g` | `384m` |
| Redis | `0.25` | `128m` | `64m` |
| Garage | `0.50` | `512m` | `128m` |
| RabbitMQ | `0.75` | `768m` | `256m` |
| Mailpit | `0.25` | `128m` | `64m` |
| Seq | `0.75` | `768m` | `256m` |
| Jaeger | `0.50` | `512m` | `128m` |
| Prometheus | `0.50` | `512m` | `128m` |
| Grafana | `0.50` | `512m` | `128m` |
| Vault | `0.50` | `512m` | `128m` |
| Portainer | `0.50` | `512m` | `128m` |
| Garage Web UI | `0.50` | `512m` | `128m` |

Adjust these in `docker-compose.yml` under the `x-resources` anchors if Docker Desktop is under memory pressure.

## First Setup

Run commands from this directory:

```bash
cd /path/to/st-poc-local-infra
cp .env.example .env
```

Review `.env` before starting anything. Host ports, credentials, and local configurable values live there.

The fastest full local setup is:

```bash
./scripts/up.sh
```

This starts all profiles, configures Garage, initializes or unseals Vault, and waits for service healthchecks.

Validate the Compose file:

```bash
docker compose config
```

Validate every profiled service:

```bash
COMPOSE_PROFILES=edge,core,broker,mail,obs,secrets,tools docker compose config
```

## Common Commands

If migrating from the previous `ss-*` local stack, stop the old containers first so the renamed `st-*` containers can bind the same ports:

```bash
docker compose -p ss-poc-local-infra down --remove-orphans
```

Start and verify everything:

```bash
./scripts/up.sh
```

Start core dependencies:

```bash
docker compose --profile core up -d
```

Start everything:

```bash
docker compose \
  --profile edge \
  --profile core \
  --profile broker \
  --profile mail \
  --profile obs \
  --profile secrets \
  --profile tools \
  up -d
```

Start one profile:

```bash
docker compose --profile edge up -d
docker compose --profile obs up -d
docker compose --profile broker up -d
docker compose --profile secrets up -d
```

Stop containers:

```bash
docker compose down
```

View logs:

```bash
docker compose logs -f
docker compose logs -f postgres
docker compose logs -f garage
```

Wait for healthchecks:

```bash
./scripts/health.sh
```

Reset all local data:

```bash
docker compose down -v
```

This deletes named volumes for databases, object storage, Vault, Grafana, Seq, Prometheus, RabbitMQ, and Portainer.

## Useful URLs

Defaults below assume the values from `.env.example`.

| Service | URL |
| --- | --- |
| Traefik reverse proxy | `http://localhost:8088` |
| Traefik dashboard | `http://localhost:8081/dashboard/` |
| App route via Traefik | `http://app.local:8088` |
| Auth route via Traefik | `http://auth.local:8088` |
| Garage S3 API | `http://localhost:3900` |
| Garage Admin API | `http://localhost:3903` |
| Garage Health | `http://localhost:3903/health` |
| RabbitMQ Management | `http://localhost:15672` |
| Mailpit | `http://localhost:8025` |
| Seq | `http://localhost:5340` |
| Jaeger | `http://localhost:16686` |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |
| Vault | `http://localhost:8200` |
| Garage Web UI | `http://localhost:3909` |
| Portainer | `http://localhost:9002` |

## App Connection Values

Use `localhost` from your host machine and Docker service names from app containers.

| Dependency | Host machine | From another container |
| --- | --- | --- |
| Traefik web entrypoint | `http://localhost:${TRAEFIK_WEB_PORT}` | `http://traefik` |
| Postgres | `localhost:${POSTGRES_PORT}` | `postgres:5432` |
| MongoDB | `localhost:${MONGO_PORT}` | `mongo:27017` |
| Redis | `localhost:${REDIS_PORT}` | `redis:6379` |
| RabbitMQ | `localhost:${RABBITMQ_PORT}` | `rabbitmq:5672` |
| Garage S3 | `http://localhost:${GARAGE_S3_PORT}` | `http://garage:3900` |
| Garage bucket | `${GARAGE_BUCKET}` | `${GARAGE_BUCKET}` |
| Garage region | `garage` | `garage` |
| Mailpit SMTP | `localhost:${MAILPIT_SMTP_PORT}` | `mailpit:1025` |
| Seq ingest | `http://localhost:${SEQ_INGEST_PORT}` | `http://seq:5341` |
| OTLP gRPC | `localhost:${JAEGER_OTLP_GRPC_PORT}` | `jaeger:4317` |
| OTLP HTTP | `http://localhost:${JAEGER_OTLP_HTTP_PORT}` | `http://jaeger:4318` |
| Vault | `http://localhost:${VAULT_PORT}` | `http://vault:8200` |

## Edge Proxy

The `edge` profile starts Traefik as the local reverse proxy and load balancer. It listens on `TRAEFIK_WEB_PORT` for app traffic and `TRAEFIK_DASHBOARD_PORT` for the local dashboard.

Start it:

```bash
docker compose --profile edge up -d traefik
```

Preconfigured local routes:

| Host | Target |
| --- | --- |
| `app.local`, `app.localhost` | Garage Web UI at `garage-webui:3909` |
| `auth.local`, `auh.local`, `auth.localhost` | Vault at `vault:8200` |

These are defined in `traefik/dynamic/local-routes.yaml`. Replace the targets when your real app and auth services are available.

Traefik uses the file provider in `traefik/dynamic`. This avoids mounting the Docker socket into the proxy and keeps routing explicit.

To route to an Ocelot gateway, copy the example route:

```bash
cp traefik/examples/ocelot-gateway.yaml traefik/dynamic/ocelot-gateway.yaml
```

Then run the Ocelot gateway container on `st_poc_shared` with the network alias `ocelot-gateway`, or update the server URL in the dynamic route:

```yaml
services:
  ocelot-gateway:
    image: your-ocelot-gateway-image
    networks:
      st_poc_shared:
        aliases:
          - ocelot-gateway
```

For multiple stable gateway instances, add more servers under `loadBalancer.servers` in `traefik/dynamic/ocelot-gateway.yaml`:

```yaml
services:
  ocelot-gateway:
    loadBalancer:
      servers:
        - url: http://ocelot-gateway-a:8080
        - url: http://ocelot-gateway-b:8080
```

## Garage

Garage replaces MinIO as the local S3-compatible object store.

Compose mounts:

- Config: `./garage/garage.toml:/etc/garage.toml:ro`
- Metadata: `st_poc_garage_meta:/var/lib/garage/meta`
- Data: `st_poc_garage_data:/var/lib/garage/data`

Start Garage:

```bash
docker compose --profile core up -d garage
```

Configure the single-node local layout, default bucket, and default app key:

```bash
./scripts/setup-garage.sh
```

Check status:

```bash
docker compose logs garage
docker compose exec garage garage status
```

Garage requires one-time local node/layout setup before buckets and S3 keys are usable. `./scripts/setup-garage.sh` is idempotent for the layout, bucket, and key name in `.env`.

The default bucket is `${GARAGE_BUCKET}`. The generated S3 access key output is written to `garage/.garage-${GARAGE_KEY_NAME}.txt`, which is ignored by git. If the key already exists but that local file is missing, recreate the key or create a new key name; Garage does not show an existing secret key again.

Garage itself does not include a browser UI. The `core` profile starts Garage Web UI at `http://localhost:${GARAGE_WEBUI_PORT}` for local bucket and object management.

## Vault

Vault runs with persistent local file storage, not dev mode.

Compose mounts:

- Config: `./vault/config/vault.hcl:/vault/config/vault.hcl:ro`
- Data: `st_poc_vault_data:/vault/file`
- Logs: `st_poc_vault_logs:/vault/logs`

This keeps Vault data across container restarts. It is still a single-node local POC Vault, not production HA Vault.

Start Vault:

```bash
docker compose --profile secrets up -d vault
```

Initialize Vault after first startup:

```bash
./scripts/unseal-vault.sh
```

The script initializes Vault if needed with one local unseal key, writes the generated init material to `vault/.vault-init.json`, and unseals Vault. That file is ignored by git and should stay local/private.

Unseal Vault after Docker or the Vault container restarts:

```bash
./scripts/unseal-vault.sh
```

Log in:

```bash
docker compose exec vault vault login <token-from-vault/.vault-init.json>
```

Check status:

```bash
docker compose exec vault vault status
```

## Observability

The `obs` profile starts:

- Seq for structured application logs
- Jaeger all-in-one with OTLP gRPC and OTLP HTTP enabled
- Prometheus with local scrape config
- Grafana with persistent local storage

Start observability:

```bash
docker compose --profile obs up -d
```

Default OTLP targets for .NET apps:

```text
OTLP gRPC: http://localhost:4317
OTLP HTTP: http://localhost:4318
```

Use Docker service names when the app itself runs inside Compose:

```text
OTLP gRPC: http://jaeger:4317
OTLP HTTP: http://jaeger:4318
Seq:       http://seq:5341
```

## Future App Services

Do not add `depends_on` between independent infrastructure services. For future application containers, depend on healthy infrastructure services only where startup ordering matters.

Example:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
  rabbitmq:
    condition: service_healthy
```

## Files

| Path | Purpose |
| --- | --- |
| `docker-compose.yml` | Local infrastructure stack |
| `.env.example` | Required environment variables and default local values |
| `garage/garage.toml` | Garage local config |
| `prometheus/prometheus.yml` | Prometheus local scrape config |
| `traefik/dynamic/local-routes.yaml` | Preconfigured local Traefik routes |
| `traefik/examples/ocelot-gateway.yaml` | Example file-provider route for an Ocelot gateway |
| `vault/config/vault.hcl` | Persistent local Vault config |
| `scripts/up.sh` | Start all profiles, configure Garage, unseal Vault, and wait for health |
| `scripts/setup-garage.sh` | Configure Garage layout, bucket, and app key |
| `scripts/unseal-vault.sh` | Initialize or unseal local Vault from ignored init material |
| `scripts/health.sh` | Wait for all Compose healthchecks |

## Troubleshooting

If Docker Desktop reports healthcheck timeouts like `timed out starting health check` and `docker restart` or `docker kill` cannot stop the affected container, Docker Desktop's VM/container lifecycle is wedged. Restart Docker Desktop, then run:

```bash
./scripts/up.sh
```
