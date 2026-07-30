# WZI Core Stack

## Overview

WZI Core Stack is the production infrastructure for the WZI SaaS Platform.

It provides a secure, containerized environment consisting of:

- Caddy Reverse Proxy
- PostgreSQL 17
- Redis 7
- n8n Automation
- Docker Compose
- GitHub Version Control

---

## Architecture

Internet
↓
Cloudflare
↓
Caddy (HTTPS)
├── n8n.wzisaas.com
└── app.wzisaas.com
↓
Docker Network
├── PostgreSQL
├── Redis
└── WZI SaaS Application

---

## Repository Structure

```
compose*.yml         Docker Compose configuration
scripts/             Operational scripts
systemd/             Service and timer definitions
docs/                Documentation
proxy/               Caddy configuration
postgres/            PostgreSQL persistent data
redis/               Redis persistent data
n8n/                 n8n persistent data
```

---

## Current Release

Production Infrastructure v1.1.0

---

## Components

- Ubuntu 24.04 LTS
- Docker Engine
- Docker Compose
- PostgreSQL 17
- Redis 7
- n8n
- Caddy 2
- Cloudflare

---

## Backup

Automated PostgreSQL backup runs daily using systemd.

Backups are stored under:

```
/opt/wzi/backups/postgres
```

Each backup is accompanied by a SHA-256 checksum.

---

## Documentation

See the docs directory for:

- Architecture
- Deployment
- Operations
- Disaster Recovery
- Release Notes
