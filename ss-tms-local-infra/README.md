# ss-tms-local-infra

Local, cloud-neutral infrastructure stack for the **ss-tms** microservices ecosystem.

This repository provides a **single Docker-based environment** that all TMS microservices connect to during development.
It mirrors production architecture while remaining portable across **AWS, GCP, and Azure**.

> Philosophy: **one local infra stack, many services**

---

## What this repo is for
- Run shared dependencies locally (databases, storage, cache)
- Avoid duplicating Docker setup in every microservice repo
- Keep service repos focused on **application code only**
- Stay cloud-agnostic from day one

This repo is **development-only**. In production, each dependency is replaced with its managed cloud equivalent.

---

## Included services

| Service     | Purpose | Cloud replacement |
|------------|--------|------------------|
| PostgreSQL | Primary relational database (multi-tenant) | RDS / Cloud SQL / Azure PostgreSQL |
| MongoDB    | Event/timeline & flexible document store | MongoDB Atlas |
| MinIO      | S3-compatible object storage (PDFs, images) | AWS S3 / GCS / Azure Blob |
| Redis      | Cache, locks, background jobs | ElastiCache / Memorystore / Azure Cache |
| Docker     | Orchestration layer | Kubernetes / App Service / Cloud Run |

---

## Quick start

### 1) Prerequisites
- Docker Desktop
- JetBrains DataGrip (recommended)
- MongoDB Compass (optional, but nice)

---

### 2) Start the infrastructure stack

```bash
docker compose --env-file .env up -d
```

Verify:
```bash
docker compose ps
```

To stop:
```bash
docker compose down
```

To **reset all local data** (destructive):
```bash
docker compose down -v
```

---

## Connection details (for microservices & tools)

### PostgreSQL
From your **host machine** (DataGrip, local dotnet run):

```
Host: localhost
Port: 5432
Database: tms
User: tms
Password: tms_local_pw
```

.NET connection string:
```
Host=localhost;Port=5432;Database=tms;Username=tms;Password=tms_local_pw
```

From **another Docker container**:
```
Host=postgres
Port=5432
Database=tms
User=tms
Password=tms_local_pw
```

---

### MongoDB
Connection string (host machine):

```
mongodb://root:mongo_local_pw@localhost:27017
```

Inside Docker:
```
mongodb://root:mongo_local_pw@mongo:27017
```
---

### MinIO (S3-compatible storage)
- API endpoint: http://localhost:9000
- Console UI: http://localhost:9001

Credentials:
```
Access Key: minioadmin
Secret Key: minioadmin_pw
```

Default bucket:
```
tms-files
```

S3-style configuration for services:
```
Endpoint: http://localhost:9000
Bucket: tms-files
ForcePathStyle: true
```

Inside Docker:
```
Endpoint: http://minio:9000
```

---

### Redis
Host machine:
```
localhost:6379
```

Inside Docker:
```
redis:6379
```