# ss-poc-local-infra

Local, cloud-neutral infrastructure stack for the **ss-poc** microservices ecosystem.

This repository provides a **single Docker-based environment** that all ss-poc microservices connect to during development.
It mirrors a real production architecture while remaining portable across **AWS, GCP, and Azure**.


---

## What this repo is for

- Run **shared dependencies locally** (databases, storage, cache, messaging)
- Avoid duplicating Docker setup in every microservice repo
- Keep service repos focused on **application code only**
- Enforce consistent infra patterns across all services
- Stay **cloud-agnostic** from day one

This repo is **development-only**.  

---

## Included services

| Service | Purpose | Cloud replacement |
|------|------|------|
| PostgreSQL | Primary relational database (multi-tenant core data) | RDS / Cloud SQL / Azure PostgreSQL |
| MongoDB | Events, timelines, flexible documents | MongoDB Atlas |
| MinIO | S3-compatible object storage (PDFs, images, inspections) | AWS S3 / GCS / Azure Blob |
| Redis | Cache, locks, rate limiting, background jobs | ElastiCache / Memorystore / Azure Cache |
| RabbitMQ | Async workflows & integrations | Amazon MQ / Cloud Pub/Sub / Azure Service Bus |
| Mailpit | Local SMTP + inbox for email testing | SES / SendGrid / Mailgun |
| Vault (dev mode) | Local secrets management | AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |
| Prometheus | Metrics store | Managed Prometheus |
| Grafana | Metrics dashboards | Managed Grafana |
| Jaeger | Distributed tracing UI | Cloud tracing |
| Traefik | Local gateway / reverse proxy | API Gateway / Ingress |
| Docker Compose | Local orchestration | Kubernetes / App Service / Cloud Run |

---

## Architecture intent

- **Postgres** = source of truth (equipment, drivers, loads, tenants)
- **MongoDB** = append-only / flexible data (events, GPS, provider payloads)
- **MinIO** = documents & media (never store blobs in Postgres)
- **Redis** = fast, disposable state
- **RabbitMQ** = async boundaries between services
- **Vault** = secrets abstraction (env-first, Vault optional)
- **Observability** = built in from day one, not bolted on later

---

## Prerequisites

- Docker Desktop
- JetBrains **DataGrip** (recommended)
- MongoDB Compass (optional)

---

## Running the stack

### Start core infrastructure (recommended default)
xdocker compose -f compose.yaml \
  --profile core \
  --profile mail \
  --profile broker \
  --profile obs \
  --profile gateway \
  --profile secrets \
  up -d --build

Core includes:
- Postgres
- MongoDB
- MinIO (+ bucket init)
- Redis

---

### Start optional components when needed

Mail (email testing):
docker compose --env-file .env --profile mail up -d

Message broker:
docker compose --env-file .env --profile broker up -d

Observability:
docker compose --env-file .env --profile obs up -d

Gateway:
docker compose --env-file .env --profile gateway up -d

Secrets (Vault dev mode):
docker compose --env-file .env --profile secrets up -d

---

### Stop everything
docker compose down

### Reset **all local data** (destructive)
docker compose down -v

---

## Profiles summary

| Profile | What it runs |
|------|------|
| `core` | Postgres, MongoDB, MinIO, Redis |
| `mail` | Mailpit |
| `broker` | RabbitMQ |
| `obs` | Prometheus, Grafana, Jaeger |
| `gateway` | Traefik |
| `secrets` | Vault (dev mode) |

---

## Connection details

### PostgreSQL

- Host: localhost
- Port: 5432
- Database: poc
- User: poc
- Password: poc_local_pw
- Host=localhost;Port=5432;Database=poc;Username=poc;Password=poc_local_pw
- Docker Host=postgres;Port=5432;Database=poc;Username=poc;Password=poc_local_pw

---

### MongoDB

- Host machine: mongodb://root:mongo_local_pw@localhost:27017
- Docker:mongodb://root:mongo_local_pw@mongo:27017

---

### MinIO

- API: http://localhost:9000
- Console: http://localhost:9001

Credentials:
- Access key: minioadmin
- Secret key: minioadmin_pw

Service configuration:
- Endpoint: http://localhost:9000
- Bucket: poc-files
- ForcePathStyle: true
- Docker Endpoint: http://minio:9000
---

### Redis

- localhost:6379
- Inside Docker: redis:6379

---

### Mailpit (email testing)

- UI: http://localhost:8025
- SMTP: localhost:1025
- No auth, no TLS (local only)

---

### Vault (dev mode)

- Address: http://localhost:8200
---

### Observability

- Jaeger UI: http://localhost:16686
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 
