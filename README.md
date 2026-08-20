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

### Current Certified Release Baseline

**WZI Core Stack v1.5.0**

Frozen tag:

`v1.5.0`

Frozen commit:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

### Current Release-Validation Candidate

**WZI Core Stack v1.6.0**

Release branch:

`release/v1.6.0`

Current certified branch commit:

`dd051843a77e7a70378208e1b3b39f299c5fe1da`

Status:

Milestone 6F — Release Validation and Documentation.

The v1.6.0 release tag has not been authorized by this documentation
candidate. Final release tagging remains subject to separate explicit
release authorization.

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
