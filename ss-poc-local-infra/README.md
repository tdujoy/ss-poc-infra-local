# ss-poc-local-infra

Local Docker infrastructure for the **ss-poc** .NET microservices POC.

This stack is for local development only. It gives service repos shared dependencies and developer tools without adding Kubernetes, cloud deployment files, or production assumptions.

## Included Services

| Profile | Services |
| --- | --- |
| `core` | Postgres, MongoDB, Redis, Garage |
| `broker` | RabbitMQ with management UI |
| `mail` | Mailpit |
| `obs` | Seq, Jaeger, Prometheus, Grafana |
| `secrets` | Vault |
| `tools` | Portainer |

All services use the shared Docker network `ss_poc_shared`. Persistent services use named Docker volumes.

## First Setup

Run commands from this directory:

```bash
cd ss-poc-local-infra
cp .env.example .env
```

Review `.env` before starting anything. Host ports, credentials, and local configurable values live there.

Validate the Compose file:

```bash
docker compose config
```

Validate every profiled service:

```bash
COMPOSE_PROFILES=core,broker,mail,obs,secrets,tools docker compose config
```

## Common Commands

Start core dependencies:

```bash
docker compose --profile core up -d
```

Start everything:

```bash
docker compose \
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

Reset all local data:

```bash
docker compose down -v
```

This deletes named volumes for databases, object storage, Vault, Grafana, Seq, Prometheus, RabbitMQ, and Portainer.

## Useful URLs

Defaults below assume the values from `.env.example`.

| Service | URL |
| --- | --- |
| Garage S3 API | `http://localhost:3900` |
| Garage Admin API | `http://localhost:3903` |
| RabbitMQ Management | `http://localhost:15672` |
| Mailpit | `http://localhost:8025` |
| Seq | `http://localhost:5340` |
| Jaeger | `http://localhost:16686` |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |
| Vault | `http://localhost:8200` |
| Portainer | `http://localhost:9000` |

## App Connection Values

Use `localhost` from your host machine and Docker service names from app containers.

| Dependency | Host machine | From another container |
| --- | --- | --- |
| Postgres | `localhost:${POSTGRES_PORT}` | `postgres:5432` |
| MongoDB | `localhost:${MONGO_PORT}` | `mongo:27017` |
| Redis | `localhost:${REDIS_PORT}` | `redis:6379` |
| RabbitMQ | `localhost:${RABBITMQ_PORT}` | `rabbitmq:5672` |
| Garage S3 | `http://localhost:${GARAGE_S3_PORT}` | `http://garage:3900` |
| Mailpit SMTP | `localhost:${MAILPIT_SMTP_PORT}` | `mailpit:1025` |
| Seq ingest | `http://localhost:${SEQ_INGEST_PORT}` | `http://seq:5341` |
| OTLP gRPC | `localhost:${JAEGER_OTLP_GRPC_PORT}` | `jaeger:4317` |
| OTLP HTTP | `http://localhost:${JAEGER_OTLP_HTTP_PORT}` | `http://jaeger:4318` |
| Vault | `http://localhost:${VAULT_PORT}` | `http://vault:8200` |

## Garage

Garage replaces MinIO as the local S3-compatible object store.

Compose mounts:

- Config: `./garage/garage.toml:/etc/garage.toml:ro`
- Metadata: `ss_poc_garage_meta:/var/lib/garage/meta`
- Data: `ss_poc_garage_data:/var/lib/garage/data`

Start Garage:

```bash
docker compose --profile core up -d garage
```

Check status:

```bash
docker compose logs garage
docker compose exec garage garage status
```

Garage may require one-time local node/layout setup before buckets and S3 keys are usable. After first startup, inspect the logs and status output, then create the local layout, bucket, and access keys needed by your app.

## Vault

Vault runs with persistent local file storage, not dev mode.

Compose mounts:

- Config: `./vault/config/vault.hcl:/vault/config/vault.hcl:ro`
- Data: `ss_poc_vault_data:/vault/file`
- Logs: `ss_poc_vault_logs:/vault/logs`

This keeps Vault data across container restarts. It is still a single-node local POC Vault, not production HA Vault.

Start Vault:

```bash
docker compose --profile secrets up -d vault
```

Initialize Vault after first startup:

```bash
docker compose exec vault vault operator init
```

Save the unseal keys and initial root token somewhere local and private. They are not stored in this repo.

Unseal Vault:

```bash
docker compose exec vault vault operator unseal <unseal-key-1>
docker compose exec vault vault operator unseal <unseal-key-2>
docker compose exec vault vault operator unseal <unseal-key-3>
```

Log in:

```bash
docker compose exec vault vault login <initial-root-token>
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
| `vault/config/vault.hcl` | Persistent local Vault config |
