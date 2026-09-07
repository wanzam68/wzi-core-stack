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

## Supported Ranges

The dashboard supports the following historical telemetry
ranges:

- 24h
- 7d
- 30d

The selected range is requested through:

`GET /api/history.php?range=<range>`

Only the supported values above are valid dashboard range
selections.

## Range Selection Semantics

Historical consumers in the dashboard must use the active
operator-selected range consistently.

This applies to:

- historical summary data
- historical resource and infrastructure charts
- Operational Intelligence historical comparisons
- service restart trend comparisons
- operator historical analytics refreshes

Changing the historical range must cause subsequent historical
requests to use the newly selected range.

If the control is absent or an unsupported value is encountered,
the browser falls back to `24h`.

Historical telemetry failure remains fail-safe: live operational
monitoring can continue even when historical comparison data is
temporarily unavailable.

## Bucket Sizes

Current range-specific bucket sizes are:

- 24h: 300 seconds (5 minutes)
- 7d: 1800 seconds (30 minutes)
- 30d: 3600 seconds (60 minutes)

These bucket sizes describe the existing exported historical
datasets and do not change the API schema.

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
