# WZI Enterprise Operations Dashboard

## Release

WZI Core Stack v1.5.0

## Purpose

The WZI Enterprise Operations Dashboard provides a centralized
operational view of the WZI Core Stack infrastructure.

## Initial Modules

- Executive Summary
- Infrastructure Health
- Service Health
- Host Resource Usage
- PostgreSQL Backup Status
- SSL Certificate Status
- Monitoring History
- Alert Timeline
- Release Information

## Architecture

Browser
  -> Dashboard
  -> Controlled Read-Only API
  -> Monitoring Framework
  -> Historical PostgreSQL Storage

## Security Principles

1. No infrastructure secrets are exposed to the browser.
2. The dashboard must never expose the core-stack .env file.
3. Initial dashboard functionality is read-only.
4. Privileged operational actions require a separate controlled gateway.
5. Monitoring scripts remain outside the public web root.
6. API responses expose only explicitly approved operational data.
7. All future administrative actions must be authenticated and audited.

## Release Governance

Development Branch:
release/v1.5.0

Baseline:
WZI Core Stack v1.4.0

Target:
WZI Core Stack v1.5.0
Enterprise Operations Dashboard & Automation
