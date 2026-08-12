# WZI Historical Telemetry API Contract

## Version

Schema Version: 1

Target Release:
WZI Core Stack v1.5.0

## Purpose

Provide sanitized historical infrastructure telemetry to the
WZI Enterprise Operations Dashboard without granting the web
application direct PostgreSQL access.

## Architecture

PostgreSQL
  -> host-side historical exporter
  -> sanitized history.json
  -> read-only dashboard mount
  -> history.php
  -> browser

## Initial Range

24 hours

## Initial Bucket Size

300 seconds (5 minutes)

## Supported Future Ranges

- 1h
- 6h
- 24h
- 7d
- 30d
- 90d

## Top-Level Contract

- schema_version
- generated_at
- range
- summary
- series

## Range

Fields:

- name
- from
- to
- bucket_seconds
- source_rows
- returned_points

## Summary

Includes:

- overall_status
- availability_percent
- host resource statistics
- backup summary
- SSL summary

## Host Series

Each point contains:

- timestamp
- cpu_percent
- memory_percent
- disk_percent
- load_1

## Backup Series

Each point contains:

- timestamp
- status
- age_hours

## SSL Series

Each point contains:

- timestamp
- status
- days_remaining

## Service Series

Supported services:

- docker
- postgresql
- redis
- n8n
- caddy
- dashboard

Each point contains:

- timestamp
- status
- restart_count

## Aggregation Rules

Numeric host metrics:
AVG within bucket.

Service status:
Worst state within bucket.

Severity order:

HEALTHY < WARNING < CRITICAL < UNKNOWN

Restart count:
MAX within bucket.

Backup age:
MAX within bucket.

SSL days remaining:
MIN within bucket.

## Availability

Availability is calculated from bucketed overall status.

HEALTHY:
Available.

WARNING:
Available but degraded.

CRITICAL:
Unavailable.

## Security Requirements

history.json must never contain:

- passwords
- tokens
- encryption keys
- database credentials
- environment-file contents
- Docker socket information
- SQL connection strings
- privileged filesystem paths

The dashboard remains read-only and receives only sanitized
historical operational data.
