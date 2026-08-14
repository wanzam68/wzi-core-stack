# WZI Core Stack v1.5.0 — Master End-to-End SOP

## Document Control

- System: WZI Core Stack
- Release Baseline: v1.5.0
- Release Commit: 94edcbe
- Release Branch: release/v1.5.0
- Documentation Branch: docs/v1.5.0-master-sop
- Status: Documentation Consolidation Draft
- Classification: Internal / Controlled
- Owner: WZI Resources

## 1. Purpose

This SOP documents the end-to-end deployment, operation, monitoring,
backup, recovery, historical observability, and release governance
process for WZI Core Stack v1.5.0.

## 2. Scope

This SOP covers:

- Hostinger Ubuntu VPS
- Docker and Docker Compose
- PostgreSQL
- Redis
- n8n
- Caddy reverse proxy
- Domain and SSL
- WZI Enterprise Operations Dashboard
- Live telemetry
- Historical telemetry
- PostgreSQL operations schema
- Backup and restore
- Disaster recovery
- Monitoring and Telegram alerting
- Historical retention and growth control
- systemd automation
- Git release governance
- v1.5.0 release certification

## 3. Architecture Overview

WZI Core Stack v1.5.0 is a containerized application and operations
platform deployed on an Ubuntu VPS.

The principal architecture consists of:

- Ubuntu VPS host
- Docker Engine and Docker Compose
- PostgreSQL
- Redis
- n8n
- Caddy reverse proxy
- WZI Enterprise Operations Dashboard
- PostgreSQL operations telemetry schema
- Live telemetry exporter
- Historical telemetry exporter
- Historical retention controls
- Monitoring framework
- Telegram operational alerting
- systemd-based operational automation

The release-controlled baseline is:

- Repository: `wzi-core-stack`
- Installation path: `/opt/wzi/core-stack`
- Release: `v1.5.0`
- Release commit: `94edcbe`
- Release branch: `release/v1.5.0`

The architecture separates application services, operational telemetry,
monitoring, runtime-generated data, backups, secrets, version-controlled
configuration, and release evidence.

Runtime operational data is not source code and must not be committed
to Git.

## 4. Server Access and Security Model

Administrative access is performed through SSH using the non-root
administrative account:

`wziadmin`

The primary project directory is:

`/opt/wzi/core-stack`

Root privileges are reserved for operating-system activities requiring
elevation, including systemd installation, daemon reloads, privileged
administration, and recovery operations.

Routine Docker, Git, monitoring, and repository operations should be
performed as the non-root administrative account wherever possible.

Operational security controls include:

1. Do not hardcode passwords in Compose files.
2. Do not commit `.env`.
3. Do not commit Telegram credentials.
4. Do not commit database credentials or encryption keys.
5. Do not expose PostgreSQL or Redis unnecessarily.
6. Keep dashboard telemetry mounts read-only.
7. Keep runtime telemetry, logs, and backups outside Git.
8. Perform staged secret scanning before release commits.
9. Use controlled release branches and annotated release tags.
10. Preserve the frozen release tag as a recovery baseline.

## 5. Repository and Directory Structure

The primary repository path is:

`/opt/wzi/core-stack`

Principal repository areas are:

dashboard/          Dashboard application and telemetry interface
database/           Version-controlled PostgreSQL migrations
docs/               Release documentation and controlled SOPs
scripts/monitoring/ Monitoring and telemetry automation
systemd/            Version-controlled service and timer definitions

Important generated dashboard runtime files include:

dashboard/storage/live/status.json
dashboard/storage/live/history.json

These runtime files are excluded from Git.

Other data that must remain outside version control includes:

- `.env`
- PostgreSQL runtime data
- Redis runtime data
- n8n runtime data
- Caddy runtime data
- logs
- backups
- monitoring state
- temporary files
- generated telemetry
- local safety copies

Historical safety copies and pre-change files are not authoritative
release evidence.

## 6. Environment and Secret Management

Environment-specific credentials are stored outside committed source
code.

Protected configuration may include:

- PostgreSQL credentials
- Redis password
- n8n credentials
- encryption-related values
- Telegram bot token
- Telegram chat identifier
- application secrets

The project `.env` file must remain excluded by `.gitignore`.

Monitoring components reference protected environment values rather
than embedding credential values in source code.

Before release, staged content must undergo secret scanning and manual
review.

Secrets must never be intentionally stored in:

- Markdown documentation
- Git commit messages
- release notes
- shell scripts
- Dockerfiles
- Compose definitions
- externally published screenshots

Credential recovery must use the approved secure credential repository,
not Git history.

## 7. Docker Core Stack Deployment

Docker Compose provides the primary container orchestration layer.

Before performing service changes:

```bash
cd /opt/wzi/core-stack
docker compose ps
```

Service changes should be scoped to the intended component wherever practical.

The principal production services are:

- PostgreSQL
- Redis
- n8n
- Caddy
- WZI Dashboard

After container configuration changes, validate the intended service first, followed by the consolidated monitoring framework.

### 7.1 PostgreSQL

PostgreSQL provides persistent relational storage for WZI Core Stack and contains the v1.5.0 operational telemetry schema used for historical observability.

Standalone validation:

```bash
./scripts/monitoring/postgres-health.sh
```

PostgreSQL is also validated through:

```bash
./scripts/monitoring/monitor-all.sh
```

Database credentials must be supplied through protected environment configuration and must not be hardcoded into repository files.

### 7.2 Redis

Redis provides supporting in-memory services for the WZI application stack.

Standalone validation:

```bash
./scripts/monitoring/redis-health.sh
```

Redis runtime data must remain outside Git.

### 7.3 n8n

n8n provides workflow automation capability within the WZI environment.

Standalone validation:

```bash
./scripts/monitoring/n8n-health.sh
```

Persistent n8n runtime data must remain outside version-controlled source.

### 7.4 Caddy

Caddy provides reverse-proxy and TLS/SSL functionality.

Standalone validation:

```bash
./scripts/monitoring/caddy-health.sh
```

Certificate validation is additionally performed by:

```bash
./scripts/monitoring/ssl-health.sh
```

### 7.5 Dashboard

The WZI Enterprise Operations Dashboard provides read-only operational visibility into WZI Core Stack.

The dashboard container is:

`wzi-dashboard`

The validated local host binding is:

`127.0.0.1:8088`

Primary API endpoints are:

```text
/api/status.php
/api/history.php
```

Remote administrative browser access is performed through an SSH tunnel rather than by exposing the dashboard port publicly.

## 8. Domain, Reverse Proxy and SSL

Caddy provides the reverse-proxy and TLS termination layer for WZI Core Stack.

The production architecture keeps internal application services behind the reverse proxy rather than exposing unnecessary container ports directly to the public network.

### 8.1 Reverse Proxy

Caddy is responsible for routing approved external HTTP and HTTPS traffic to the appropriate internal service.

Caddy health is validated using:

```bash
cd /opt/wzi/core-stack
./scripts/monitoring/caddy-health.sh
```

The reverse-proxy configuration should be changed only through controlled configuration changes followed by service-specific and consolidated health validation.

### 8.2 Domain and DNS

Production DNS records must resolve approved WZI service domains to the VPS hosting the Core Stack.

Before troubleshooting the application layer, verify:

1. The expected DNS record exists.
2. The record resolves to the correct VPS.
3. The reverse proxy is running.
4. The target internal service is healthy.
5. The TLS/SSL certificate is valid.

The DNS layer should not be changed as an application troubleshooting step until local service and reverse-proxy health have been verified.

### 8.3 SSL and TLS

TLS/SSL certificate health is part of the consolidated WZI monitoring baseline.

Validate certificate health using:

```bash
cd /opt/wzi/core-stack
./scripts/monitoring/ssl-health.sh
```

Caddy health should also be validated when investigating TLS/SSL issues:

```bash
./scripts/monitoring/caddy-health.sh
```

Final consolidated validation is performed with `monitor-all.sh`.

### 8.4 Dashboard Exposure Model

The WZI Enterprise Operations Dashboard is bound locally at:

`127.0.0.1:8088`

The dashboard must not be made publicly reachable merely for administrative convenience.

Administrative browser access should use the approved protected access path, including SSH tunnelling where applicable.

This preserves the principle that operational telemetry interfaces remain private unless a separately approved access-control architecture is implemented.

### 8.5 Validation

Validate the reverse-proxy, TLS/SSL, and consolidated monitoring layers with:

```bash
cd /opt/wzi/core-stack
./scripts/monitoring/caddy-health.sh
./scripts/monitoring/ssl-health.sh
./scripts/monitoring/monitor-all.sh
```

A release or infrastructure change affecting domain routing, Caddy, TLS/SSL, or dashboard exposure must not be considered operationally complete until the applicable health checks return the expected state.

## 9. PostgreSQL Database Design

PostgreSQL provides the persistent relational data layer for WZI Core Stack.

The v1.5.0 baseline also uses PostgreSQL for operational telemetry and historical observability.

Database changes must be treated as controlled changes. Schema changes used by the release must be represented by version-controlled migrations where applicable.

### 9.1 Application Databases

Application databases support the persistent data requirements of the WZI application stack.

Application data and operational telemetry should remain logically separated so that monitoring and historical reporting do not unnecessarily couple themselves to application-domain tables.

PostgreSQL credentials must not be hardcoded into migrations, scripts, or Compose definitions.

### 9.2 Operations Schema

WZI Core Stack v1.5.0 introduces a dedicated PostgreSQL `operations` schema for historical operational telemetry.

The schema supports the historical observability layer and is populated by the approved telemetry automation processes.

The operations schema is not a replacement for production application data. It is an operational evidence and observability layer.

Schema changes must be performed through controlled migrations rather than ad-hoc manual edits wherever practicable.

### 9.3 Telemetry Migrations

The release-controlled telemetry migrations are:

```text
database/migrations/001_operations_telemetry.sql
database/migrations/002_telemetry_idempotency.sql
```

Migration `001_operations_telemetry.sql` establishes the `operations` schema and the historical telemetry tables.

The operations model includes:

- `operations.telemetry_runs`
- `operations.service_health`
- `operations.host_metrics`
- `operations.backup_history`
- `operations.ssl_history`

Dependent historical tables reference the parent telemetry run using foreign-key controls. The v1.5.0 schema uses cascading deletion so that expired telemetry runs can be removed consistently with their dependent records.

Migration `002_telemetry_idempotency.sql` adds the unique control required to prevent duplicate telemetry runs for the same generated timestamp.

Database migrations must be:

1. version controlled;
2. reviewed before execution;
3. executed against the intended database;
4. run with error-stop behaviour;
5. validated after execution;
6. included in release evidence.

### 9.4 Idempotency Controls

Historical telemetry ingestion is protected against duplicate insertion.

The idempotency migration establishes uniqueness on:

`operations.telemetry_runs.generated_at`

Duplicate insertion attempts are rejected by PostgreSQL.

Historical telemetry automation also uses failure-isolation so a historical write failure does not unnecessarily disable live telemetry generation.

The idempotency control must remain intact when modifying collection or historical export automation.

## 10. Backup and Restore

PostgreSQL backups are stored under:

`/opt/wzi/backups/postgres`

The controlled backup implementation is represented by:

`scripts/postgres-backup.sh`

The backup process uses PostgreSQL dump tooling to create database backups.

The configured PostgreSQL backup retention period is:

- 14 days

Backup automation is represented by the version-controlled units:

- `systemd/wzi-postgres-backup.service`
- `systemd/wzi-postgres-backup.timer`

Backup health is independently monitored by:

`scripts/monitoring/backup-health.sh`

Backup age thresholds are:

- Warning: 26 hours
- Critical: 36 hours

Backup validation includes backup existence, freshness, file presence, and non-empty content.

### 10.1 Backup Safety Principle

A backup is not considered operationally valid merely because a backup file exists.

Operational validation should confirm:

- backup existence
- backup freshness
- backup content
- backup size
- restoration capability

### 10.2 Restore Principle

Restore operations must be performed through a controlled recovery procedure.

Before restoration:

1. Identify the intended backup.
2. Verify the backup is the intended recovery point.
3. Confirm the target database.
4. Protect existing production data.
5. Document the recovery point.
6. Perform the restoration.
7. Validate database functionality.
8. Validate dependent services.
9. Run the consolidated health monitor.

A restore test must not silently overwrite production data.

## 11. Disaster Recovery

Disaster recovery (DR) protects the ability to recover WZI Core Stack from a service failure, data loss, configuration failure, host failure, or other major operational incident.

The frozen v1.5.0 release baseline provides the version-controlled source baseline for recovery.

The primary release recovery references are:

- Release: `v1.5.0`
- Commit: `94edcbe`
- Release branch: `release/v1.5.0`

The repository baseline does not replace runtime data, database backups, secrets, or host-level recovery requirements.

### 11.1 Recovery Order

Recovery should be performed in a controlled order to reduce dependency failures.

A general recovery order is:

1. Validate the VPS and operating system.
2. Validate administrative SSH access.
3. Restore or validate the controlled repository baseline.
4. Restore protected environment configuration.
5. Validate Docker and Docker Compose.
6. Recover PostgreSQL and validate the database.
7. Recove Redis as required.
8. Recover n8n and its persistent runtime data.
9. Recover Caddy and validate reverse-proxy operation.
10. Validate DNS and TLS/SSL.
11. Recover the WZI Dashboard and telemetry automation.
12. Validate systemd timers and services.
13. Run service-specific health checks.
14. Run the consolidated health monitor.

### 11.2 Post-Recovery Validation

After recovery, validate:

- Docker container health
- PostgreSQL health
- Redis health
- n8n health
- Caddy health
- Dashboard health
- Host resources
- PostgreSQL backup health
- Telemetry growth
- SSL certificate health

Run the consolidated validation:

```bash
cd /opt/wzi/core-stack
./scripts/monitoring/monitor-all.sh
```

The system should not be declared recovered until the required operational checks have returned the expected state.

### 11.3 DR Evidence and Certification

A disaster recovery exercise should preserve evidence of:

- the recovery point used
- the repository release baseline
- the backup used
- the restore result
- the post-recovery health result
- any deviations or remediation actions

DR certification must be based on a successful restore and validation exercise, not only on the existence of backup files.

## 12. Monitoring Framework

WZI Core Stack v1.5.0 uses a consolidated monitoring framework to validate core services, host resources, backups, telemetry, and TLS/SSL health.

The principal consolidated monitor is:

`scripts/monitoring/monitor-all.sh`

The v1.5.0 certified monitoring baseline contains ten controlled checks.

### 12.1 Docker

Docker health is validated by:

`scripts/monitoring/docker-health-check.sh`

The check validates the container runtime layer and provides the foundation for service-level health checks.

### 12.2 PostgreSQL

PostgreSQL health is provided by:

`scripts/monitoring/postgres-health.sh`

The check confirms database and container operational status.

### 12.3 Redis

Redis health is validated by:

`scripts/monitoring/redis-health.sh`

The check confirms that the Redis service is available and operational.

### 12.4 n8n

n8n health is validated by:

`scripts/monitoring/n8n-health.sh`

The check validates n8n service availability and the health endpoint.

### 12.5 Caddy

Caddy health is validated by:

`scripts/monitoring/caddy-health.sh`

The check confirms the reverse-proxy service is running and healthy.

### 12.6 Dashboard

Dashboard health is validated by:

`scripts/monitoring/dashboard-health.sh`

The check validates: the container, frontend HTTP response, live API, historical API, Json contracts, telemetry freshness, Chart.js asset availability, exporter timers, and the read-only telemetry mount.

### 12.7 Host Resources

Host resource health is validated by:

`scripts/monitoring/system-health.sh`

The check includes CPU, memory, disk, inode, load-average, uptime, and Docker engine/service context.

### 12.8 PostgreSQL Backup

PostgreSQL backup health is validated by:

`scripts/monitoring/backup-health.sh`

Backup age thresholds are:

- Warning: 26 hours
- Critical: 36 hours

### 12.9 Telemetry Growth

Telemetry database growth is validated by:

`scripts/monitoring/telemetry-growth.sh`

The check protects against uncontrolled historical telemetry growth and supports retention governance.

### 12.10 SSL Certificate

SSL certificate health is validated by:

`scripts/monitoring/ssl-health.sh`

The check validates certificate status, hostname, expiry, and remaining days.

Consolidated validation is performed with:

```bash
cd /opt/wzi/core-stack
./scripts/monitoring/monitor-all.sh
```

The v1.5.0 certified baseline is:

```text
Healthy  : 10
Warnings : 0
Critical : 0
Missing  : 0

Overall Result: HEALTHY
```

## 13. Telegram Alerting and State Management

WZI Core Stack uses Telegram as an operational notification channel for meaningful changes in the consolidated monitoring state.

The alerting implementation is provided by:

`scripts/monitoring/telegram.sh`

Telegram credentials must not be hardcoded into repository files. Required credential values must be supplied through protected environment configuration.

### 13.1 State Persistence

The consolidated monitoring framework persists the last known overall monitoring state.

The v1.5.0 state file is:

`/opt/wzi/core-stack/logs/state/overall-status.state`

The previous persisted state is compared with the current consolidated state to determine whether an operational notification is required.

Runtime state files are operational data and must remain outside version control.

### 13.2 Alert Suppression

Alerts are suppressed when the consolidated monitoring state remains unchanged.

This prevents repetitive notifications for a state that has already been detected and recorded by the monitoring framework.

If the overall state remains HEALTHY, the monitor should suppress unnecessary repeat notifications.

### 13.3 Critical Alerts

When the overall consolidated state changes to CRITICAL, the monitoring framework sends a Telegram CRITICAL notification.

A critical alert indicates that at least one controlled monitor has entered a critical state or an equivalent operational failure condition.

The alert should be treated as a prompt to investigate the detailed run log and the output of the individual failing monitor.

### 13.4 Recovery Alerts

When the previously persisted overall state is CRITICAL and the current consolidated state returns to HEALTHY, the monitoring framework sends a Telegram RECOVERY notification.

The recovery notification confirms that the state engine has detected a return to the expected operational baseline.

Recovery notification does not replace root-cause review. The detailed run logs should still be retained for incident follow-up.

### 13.5 Operational Principles

The Telegram alerting layer is a notification channel and must not be treated as the sole source of operational truth.

Authoritative operational evidence includes:

- the individual monitor output
- the consolidated run log
- the persisted overall state
- the runtime service state

Telegram credentials must never be printed into operational logs or committed to Git.

Alert state transitions should remain deterministic so CRITICAL and RECOVERY notifications are sent only when the consolidated state changes meaningfully.

## 14. Enterprise Operations Dashboard

The WZI Enterprise Operations Dashboard provides read-only operational visibility into the WZI Core Stack.

The dashboard is implemented as a containerized PHP/Apache application and is exposed locally through:

`127.0.0.1:8088`

The dashboard presents live infrastructure status, service health, host resources, backup status, SSL status, release information, and historical telemetry charts.

### 14.1 Dashboard Foundation

The dashboard foundation is implemented under the `dashboard/` repository tree.

Primary implementation files include:

- `dashboard/Dockerfile`
- `dashboard/public/index.php`
- `dashboard/public/assets/css/wzi-dashboard.css`
- `dashboard/public/assets/js/wzi-dashboard.js`

The dashboard container is named:

`wzi-dashboard`

The dashboard frontend must remain operational even if administrative actions are disabled.

### 14.2 Read-Only Live API

Live monitoring data is exposed to the dashboard through:

`dashboard/public/api/status.php`

The endpoint is served locally as:

`/api/status.php`

The live API returns a structured JSON contract containing the current monitoring state, service status, host metrics, backup state, SSL state, environment, release information, and generation timestamp.

The API is read-only and must not provide privileged administrative actions.

### 14.3 Live Telemetry Scheduling

Live dashboard telemetry is produced by:

`scripts/monitoring/dashboard-export.sh`

The version-controlled systemd automation is:

- `systemd/wzi-dashboard-export.service`
- `systemd/wzi-dashboard-export.timer`

The live exporter timer operates on an approximately 60-second schedule.

Generated live telemetry is written beneath:

`dashboard/storage/live/status.json`

The generated telemetry file is runtime data and must remain outside Git.

### 14.4 Dashboard Health Monitor

Dashboard health is validated through:

`scripts/monitoring/dashboard-health.sh`

The health monitor validates the dashboard container, Docker health, restart count, frontend HTTP response, expected page content, live API response, live JSON contract, telemetry freshness, historical API response, historical JSON contract, Chart.js availability, exporter timers, and read-only telemetry mount.

The dashboard health monitor is also executed through the consolidated `monitor-all.sh` framework.

The dashboard must not be considered healthy solely because its container is running; the frontend, APIs, telemetry freshness, automation, and read-only data controls must also validate successfully.

## 15. Historical Telemetry

WZI Core Stack v1.5.0 introduces historical operational telemetry to provide time-based observability beyond the current live status snapshot.

Historical telemetry is stored in PostgreSQL and exported into a sanitized read-only JSON contract for dashboard presentation.

### 15.1 Historical Storage

Historical operational data is stored in the PostgreSQL `operations` schema.

Principal historical tables include:

- `operations.telemetry_runs`
- `operations.service_health`
- `operations.host_metrics`
- `operations.backup_history`
- `operations.ssl_history`

The historical storage model is populated by controlled telemetry automation and is protected by idempotency constraints.

### 15.2 Historical JSON Contract

The historical dashboard contract is documented in:

`dashboard/docs/HISTORICAL-API-CONTRACT.md`

The contract is exposed through:

`dashboard/public/api/history.php`

The generated runtime file is:

`dashboard/storage/live/history.json`

The historical JSON contract is sanitized and must not expose passwords, tokens, encryption keys, database connection strings, or other protected credentials.

### 15.3 Historical Exporter

Historical dashboard JSON is produced by:

`scripts/monitoring/historical-export.sh`

The v1.5.0 default historical range is 24 hours.

The historical series uses 5-minute aggregation for dashboard presentation.

The exporter validates the generated JSON contract before treating export as successful.

### 15.4 Historical API

The dashboard exposes historical telemetry through the read-only endpoint:

`/api/history.php`

The API reads the generated historical JSON and must not establish privileged write access to PostgreSQL.

### 15.5 Historical Chart UI

The dashboard historical UI uses locally vendored Chart.js.

The controlled Chart.js asset is:

`dashboard/public/assets/vendor/chartjs/chart.umd.min.js`

Historical charts present approved operational trends including host resources, load average, backup age, SSL validity, and service history.

### 15.6 Historical Export Automation

Historical export automation is represented by:

- `systemd/wzi-historical-export.service`
- `systemd/wzi-historical-export.timer`

The historical exporter runs approximately every 5 minutes.

Historical freshness is monitored by the dashboard health monitor.

## 16. Retention and Data Growth Controls

Historical telemetry is governed by an explicit retention policy so operational history does not grow indefinitely.

The v1.5.0 historical telemetry retention period is:

**90 days**

Retention is implemented by:

`scripts/monitoring/telemetry-retention.sh`

### 16.1 Retention Policy

Telemetry records older than the configured retention period are eligible for deletion.

The retention process operates on the parent telemetry run records. Dependent historical records are removed through the database foreign-key cascade controls.

The retention policy applies to operational telemetry history and is separate from PostgreSQL database-backup retention.

PostgreSQL backup retention remains 14 days, while historical telemetry retention is 90 days.

### 16.2 Backup Safety Gate

Retention deletion is protected by backup-health verification.

Before destructive retention is applied, the backup-health control must confirm that the PostgreSQL backup state is acceptable.

If backup-health validation fails, destructive telemetry retention must be aborted.

This control prevents historical data deletion from proceeding when the database backup layer is not in an acceptable state.

### 16.3 Data Growth Monitoring

Historical telemetry growth is monitored by:

`scripts/monitoring/telemetry-growth.sh`

The growth monitor provides visibility into telemetry database size and retention status and forms part of the consolidated health baseline.

Growth monitoring should be reviewed before materially changing collection frequency, retention duration, or historical schema design.

### 16.4 Retention Automation

Automated retention is represented by:

- `systemd/wzi-telemetry-retention.service`
- `systemd/wzi-telemetry-retention.timer`

The retention service executes the controlled apply mode of the telemetry-retention script.

Retention automation must remain auditable, backup-gated, and separate from live telemetry generation.

## 17. systemd Automation

WZI Core Stack uses version-controlled systemd service and timer definitions for recurring operational automation.

The repository-controlled unit files are stored under:

`systemd/`

These files provide the reproducible automation baseline for backup, live telemetry export, historical telemetry export, and telemetry retention.

### 17.1 Dashboard Live Export

Live dashboard telemetry automation is provided by:

- `systemd/wzi-dashboard-export.service`
- `systemd/wzi-dashboard-export.timer`

The service executes:

`/opt/wzi/core-stack/scripts/monitoring/dashboard-export.sh`

The timer runs approximately every 60 seconds.

### 17.2 Historical Export

Historical telemetry export automation is provided by:

- `systemd/wzi-historical-export.service`
- `systemd/wzi-historical-export.timer`

The service executes:

`/opt/wzi/core-stack/scripts/monitoring/historical-export.sh`

The timer runs approximately every 5 minutes.

### 17.3 Telemetry Retention

Historical telemetry retention automation is provided by:

- `systemd/wzi-telemetry-retention.service`
- `systemd/wzi-telemetry-retention.timer`

The service executes the retention script in controlled apply mode.

The retention timer runs daily according to the approved systemd schedule.

### 17.4 PostgreSQL Backup

PostgreSQL backup automation is provided by:

- `systemd/wzi-postgres-backup.service`
- `systemd/wzi-postgres-backup.timer`

The backup automation must remain separate from telemetry retention so backup availability can be validated independently before destructive retention actions.

### 17.5 Installation and Validation

Version-controlled unit definitions must be copied to the host systemd directory before activation.

After installation or modification:

1. Reload the systemd daemon.
2. Enable the required timer.
3. Start the timer if immediate activation is required.
4. Verify that the timer is enabled.
5. Verify that the timer is active.
6. Review recent service journal output.
7. Confirm the corresponding application or telemetry output is fresh.

Example verification commands include:

`systemctl is-enabled <timer>`
`systemctl is-active <timer>`
`systemctl list-timers --no-pager`
`journalctl -u <service> --no-pager`

Operational automation is not considered healthy solely because a timer is enabled; the resulting service execution and generated output must also validate successfully.

## 18. Operational Health Checks

Operational health validation is performed at both individual-service level and consolidated-stack level.

The authoritative consolidated monitor is:

`scripts/monitoring/monitor-all.sh`

The v1.5.0 certified monitoring baseline contains ten controlled checks.

### 18.1 Individual Health Checks

Individual monitors may be executed directly when investigating a specific component.

Principal monitors include:

- `scripts/monitoring/docker-health-check.sh`
- `scripts/monitoring/postgres-health.sh`
- `scripts/monitoring/redis-health.sh`
- `scripts/monitoring/n8n-health.sh`
- `scripts/monitoring/caddy-health.sh`
- `scripts/monitoring/dashboard-health.sh`
- `scripts/monitoring/system-health.sh`
- `scripts/monitoring/backup-health.sh`
- `scripts/monitoring/telemetry-growth.sh`
- `scripts/monitoring/ssl-health.sh`

Individual checks should be used to obtain detailed component-level evidence before or after remediation.

### 18.2 Consolidated Health Check

Execute the consolidated health monitor with:

`./scripts/monitoring/monitor-all.sh`

The consolidated monitor records a per-run evidence directory beneath:

`/opt/wzi/core-stack/logs/runs/`

The monitor summarizes HEALTHY, WARNING, CRITICAL, and MISSING results and produces an overall operational state.

### 18.3 Exit Codes

Operational scripts use exit status to indicate monitoring result.

The established monitoring model is:

- `0` — HEALTHY
- `1` — WARNING
- `2` — CRITICAL

Automation and release validation must inspect exit status in addition to displayed text.

### 18.4 Certified v1.5.0 Baseline

The certified v1.5.0 post-release monitoring result is:

- Healthy: 10
- Warnings: 0
- Critical: 0
- Missing: 0
- Overall Result: HEALTHY

This baseline represents the expected fully healthy operational state for the controlled v1.5.0 monitoring set.

### 18.5 Health Validation Principle

A container being in a running state is not sufficient evidence that the associated service is healthy.

Health validation should include the applicable combination of container status, Docker health, restart count, application response, data freshness, automation state, backup state, certificate state, and dependency health.

After maintenance, configuration change, restore, or incident remediation, the applicable individual monitor should be run first, followed by the consolidated health monitor.

## 19. Troubleshooting

Troubleshooting within WZI Core Stack should follow a controlled evidence-first process rather than immediately changing configuration.

The objective is to identify the failing layer, preserve evidence, apply the smallest corrective action, and revalidate the affected component before running the full health baseline.

### 19.1 General Troubleshooting Sequence

Use the following sequence:

1. Confirm the current Git branch and release baseline.
2. Record the current service and container state.
3. Run the applicable individual health monitor.
4. Review the latest monitor output and run log.
5. Inspect service-specific logs or systemd journal output.
6. Identify the smallest likely failure domain.
7. Apply one controlled corrective action.
8. Re-run the individual monitor.
9. Run the consolidated monitor.
10. Preserve the recovery or incident evidence.

### 19.2 Docker and Container Issues

Start with:

`docker compose ps`

Review container state, Docker health, restart count, and recent logs.

Useful evidence commands include:

`docker compose logs --tail=100 <service>`
`docker inspect <container>`

A running container must not automatically be treated as a healthy application.

### 19.3 PostgreSQL and Redis Issues

For PostgreSQL, run:

`./scripts/monitoring/postgres-health.sh`

For Redis, run:

`./scripts/monitoring/redis-health.sh`

Confirm the intended container is running, protected environment configuration is available, and the service responds to its health validation.

Do not modify database schema manually when the required change belongs in a controlled migration.

### 19.4 n8n and Caddy Issues

For n8n:

`./scripts/monitoring/n8n-health.sh`

For Caddy:

`./scripts/monitoring/caddy-health.sh`

When investigating external access problems, distinguish between application health, reverse-proxy health, DNS resolution, and TLS/SSL health before changing infrastructure.

### 19.5 Dashboard and Telemetry Issues

Run:

`./scripts/monitoring/dashboard-health.sh`

Validate the frontend, live API, historical API, telemetry freshness, Chart.js asset, exporter timers, and read-only telemetry mount.

If historical telemetry is stale, verify the historical exporter service and timer before changing the dashboard frontend.

If live telemetry is stale, verify the live dashboard exporter service and timer.

### 19.6 Backup and Retention Issues

Run:

`./scripts/monitoring/backup-health.sh`

and:

`./scripts/monitoring/telemetry-growth.sh`

Retention deletion must not be forced when backup-health validation is failing.

Backup recovery issues should be investigated independently from telemetry retention.

### 19.7 SSL and Certificate Issues

Run:

`./scripts/monitoring/ssl-health.sh`

Validate hostname, certificate validity, certificate expiry, Caddy health, DNS resolution, and upstream application response.

### 19.8 systemd Automation Issues

For timer-driven automation, validate both the timer and the service execution.

Useful commands include:

`systemctl is-enabled <timer>`
`systemctl is-active <timer>`
`systemctl list-timers --no-pager`
`journalctl -u <service> --no-pager`

An enabled timer is not sufficient evidence that the automation is producing fresh output.

### 19.9 Post-Remediation Validation

After remediation, first rerun the relevant individual monitor.

Then run:

`./scripts/monitoring/monitor-all.sh`

The incident should not be considered resolved until the expected operational state is restored and the consolidated monitor result is acceptable.

## 20. Release and Git Governance

WZI Core Stack releases are governed through controlled Git branches, immutable release tags, documented release evidence, and separation of version-controlled source from runtime-generated state.

### 20.1 v1.5.0 Release Baseline

The certified WZI Core Stack v1.5.0 release baseline is:

- Release: `v1.5.0`
- Release commit: `94edcbe81bf2d0c99f6b57601c349189cc0a866b`
- Release branch: `release/v1.5.0`
- Remote release branch: `origin/release/v1.5.0`
- Documentation branch: `docs/v1.5.0-master-sop`
- Release note: `docs/releases/v1.5.0.md`

The release branch, remote release branch, release tag, and documentation branch baseline resolve to the same certified release commit.

The release tag `v1.5.0` is an annotated Git tag and represents the frozen version-controlled recovery and release baseline.

### 20.2 Release Branch Governance

Release development is consolidated onto a controlled release branch before release freeze.

For v1.5.0, the controlled release branch is:

`release/v1.5.0`

The remote release branch is:

`origin/release/v1.5.0`

At the certified baseline, both references resolve to:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

Release branches must not be treated as runtime storage locations. Runtime-generated telemetry, logs, backups, state files, credentials, and environment-specific data remain outside the version-controlled release baseline.

### 20.3 Release Tag Governance

The certified release tag is:

`v1.5.0`

The tag resolves to release commit:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

The release tag provides an immutable reference to the certified source baseline.

A release tag must identify the source state that passed release validation. Subsequent documentation or operational work must not silently redefine the source represented by the frozen release tag.

### 20.4 Documentation Branch Governance

Release documentation consolidation is performed on the dedicated documentation branch:

`docs/v1.5.0-master-sop`

The documentation branch was created from the certified v1.5.0 release baseline so documentation work can proceed without modifying the frozen release source baseline.

Documentation consolidation must preserve the distinction between:

1. Certified release source.
2. Documentation created after release freeze.
3. Runtime-generated operational state.
4. Secrets and environment-specific configuration.
5. Backup and historical telemetry data.
6. Temporary and safety-copy artifacts.

The Master SOP and Evidence Index provide documentation of the release but do not replace the Git tag and release commit as the source-code baseline.

### 20.5 Repository Source-of-Truth Controls

Authoritative release evidence includes version-controlled application configuration, scripts, migrations, systemd units, dashboard source, monitoring source, and release documentation.

Runtime-generated files are not authoritative source files.

Examples include:

- `dashboard/storage/live/status.json`
- `dashboard/storage/live/history.json`
- `logs/`
- `backups/`
- monitoring runtime state
- database runtime storage

Safety copies and temporary migration artifacts must also not be treated as authoritative release source.

Examples include:

- `dashboard/public/*.pre-5f-e`
- `scripts/monitoring/*.pre-telegram`
- `scripts/monitoring/*.pre-history`
- `scripts/monitoring/*.pre-atomic*`
- `scripts/monitoring-pre-refactor-*/`

### 20.6 Secret and Runtime Exclusion Controls

Secrets and runtime-generated data must remain outside Git.

The repository `.gitignore` provides controls for categories including:

- `.env` and environment files
- PostgreSQL runtime data
- Redis runtime data
- n8n runtime data
- Caddy runtime data and logs
- backups
- logs
- monitoring runtime logs and state
- dashboard runtime storage
- temporary files
- local monitoring safety copies

Environment-managed credentials must not be converted into release evidence or committed to the repository.

The presence of a source file whose name refers to Telegram, backup, monitoring, or another protected subsystem does not itself indicate that secrets or runtime data are tracked. Source scripts and service definitions remain version-controlled where required; credentials and generated operational state remain excluded.

### 20.7 Release Evidence Integrity

Release certification must be based on reproducible evidence rather than mutable runtime files.

For v1.5.0, release evidence includes:

- the frozen release commit
- the annotated release tag
- the controlled release branch
- the release note
- the Documentation Evidence Index
- version-controlled source files
- recorded runtime validation results

The Documentation Evidence Index must distinguish release evidence from non-authoritative runtime and safety-copy artifacts.

Runtime data and secrets must never be committed solely for the purpose of preserving documentation evidence.

### 20.8 Git Verification

The certified release baseline can be verified with:

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

For the certified v1.5.0 baseline, each command must resolve to:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

The tag type can be verified with:

`git cat-file -t v1.5.0`

Expected result:

`tag`

Working-tree changes must be reviewed separately from the frozen release baseline using:

`git status --short`

Documentation consolidation changes on `docs/v1.5.0-master-sop` must not be interpreted as modifications to the already frozen `v1.5.0` release tag.

### 20.9 Governance Principle

Git history establishes the version-controlled release baseline.

Operational runtime state establishes the current system state.

Documentation records how the certified system was built, operated, validated, recovered, and governed.

These three forms of evidence serve different purposes and must remain distinguishable throughout release, recovery, audit, and future change-control activities.

## 21. v1.5.0 Release Validation

WZI Core Stack v1.5.0 release validation confirms that the frozen Git release baseline and the deployed operational environment satisfy the certified monitoring and dashboard health requirements.

Release validation must evaluate both version-controlled release identity and current runtime health. A valid Git tag alone is not sufficient evidence of an operationally healthy release, and a healthy runtime alone does not replace the frozen source baseline.

### 21.1 Certified Release Identity

The certified v1.5.0 release identity is:

- Release: `v1.5.0`
- Release commit: `94edcbe81bf2d0c99f6b57601c349189cc0a866b`
- Release branch: `release/v1.5.0`
- Remote release branch: `origin/release/v1.5.0`

The following release references must resolve to the same certified commit:

`git rev-parse HEAD`

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

Expected commit:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

Release identity drift must be investigated before the release can be treated as matching the certified baseline.

### 21.2 Certified Monitoring Baseline

The certified v1.5.0 monitoring baseline contains ten controlled health checks:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

The certified healthy baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`

This baseline represents the expected fully healthy operational state for the controlled v1.5.0 monitoring set.

### 21.3 Consolidated Release Health Validation

Run:

`./scripts/monitoring/monitor-all.sh`

Release validation must inspect both the displayed health result and the command exit status.

The accepted v1.5.0 result is:

- Docker: `HEALTHY`
- PostgreSQL: `HEALTHY`
- Redis: `HEALTHY`
- n8n: `HEALTHY`
- Caddy: `HEALTHY`
- Dashboard: `HEALTHY`
- Host Resources: `HEALTHY`
- PostgreSQL Backup: `HEALTHY`
- Telemetry Growth: `HEALTHY`
- SSL Certificate: `HEALTHY`
- Overall Result: `HEALTHY`
- Monitor exit status: `0`

A displayed `HEALTHY` result must not be treated as complete automation evidence unless the consolidated monitor also exits successfully.

### 21.4 Dashboard Release Validation

Run:

`./scripts/monitoring/dashboard-health.sh`

The dashboard health monitor validates the release-facing dashboard and historical observability path.

The accepted v1.5.0 dashboard baseline includes:

- dashboard container exists
- container status is running
- Docker health is healthy
- container restart count is zero
- frontend HTTP status is `200`
- expected dashboard page is detected
- monitoring API HTTP status is `200`
- monitoring API returns valid JSON
- monitoring API contract validates
- live telemetry is fresh
- historical API HTTP status is `200`
- historical API returns valid JSON
- historical API contract validates
- historical telemetry is fresh
- local Chart.js asset returns HTTP `200`
- historical exporter timer is active
- historical exporter timer is enabled
- live telemetry exporter timer is active
- live telemetry exporter timer is enabled
- telemetry data mount is read-only
- Overall Result is `HEALTHY`
- dashboard health exit status is `0`

These checks validate the dashboard container, HTTP delivery, API contracts, telemetry freshness, historical observability, automation state, local chart dependency, and read-only telemetry exposure.

### 21.5 Release Acceptance Criteria

The v1.5.0 runtime release baseline is acceptable when all of the following are true:

1. The Git release references resolve to the certified release commit.
2. All ten consolidated monitors execute successfully.
3. Healthy count is `10`.
4. Warning count is `0`.
5. Critical count is `0`.
6. Missing count is `0`.
7. Consolidated Overall Result is `HEALTHY`.
8. `monitor-all.sh` exits with status `0`.
9. Dashboard Overall Result is `HEALTHY`.
10. `dashboard-health.sh` exits with status `0`.
11. Live telemetry is fresh.
12. Historical telemetry is fresh.
13. Required telemetry exporter timers are active and enabled.
14. Dashboard telemetry storage remains read-only.
15. No release identity drift is detected.

Failure of a mandatory acceptance criterion requires investigation before the runtime state can be treated as matching the certified v1.5.0 release baseline.

### 21.6 Exit-Status Governance

Release validation must preserve exit-status semantics.

A monitor that prints a healthy-looking message but exits unsuccessfully has not passed automated release validation.

For the certified baseline:

`MONITOR_ALL_EXIT=0`

`DASHBOARD_HEALTH_EXIT=0`

Automation, release certification, and future operational validation must inspect exit codes in addition to human-readable output.

### 21.7 Current Certified Validation State

At the certified v1.5.0 validation state, the consolidated monitor reports:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`

The dashboard health monitor also reports:

- Overall Result: `HEALTHY`

The corresponding validation commands return successful exit status.

This state represents the expected healthy operational condition for WZI Core Stack v1.5.0.

### 21.8 Release Validation Principle

Release certification combines three forms of evidence:

1. Frozen Git release identity.
2. Version-controlled release documentation and configuration.
3. Successful runtime health validation.

No single form of evidence replaces the others.

The frozen Git baseline establishes what was released. Runtime health validation establishes whether the deployed environment is operating correctly. Documentation records the controls, evidence, procedures, and acceptance criteria required to reproduce and audit the release state.

## 22. Recovery Validation Checklist

Recovery validation confirms that WZI Core Stack has returned to an acceptable operational state after a restore, host recovery, service recovery, configuration recovery, or major incident remediation.

Recovery must be validated against both the intended recovery point and the certified operational baseline. The existence of source code, a Git tag, a backup file, or running containers alone is not sufficient evidence of successful recovery.

### 22.1 Recovery Preconditions

Before beginning a controlled recovery, confirm:

- [ ] The incident or recovery scope has been identified.
- [ ] The intended recovery point has been identified.
- [ ] The certified release baseline required for recovery has been identified.
- [ ] Required protected environment configuration and credentials are available through the approved secure mechanism.
- [ ] The intended PostgreSQL backup set has been identified where database restoration is required.
- [ ] Existing production data will not be silently overwritten by an unvalidated restore operation.
- [ ] Recovery actions and evidence will be recorded.

For the certified v1.5.0 source baseline, the expected release commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

### 22.2 Release Baseline Validation

The version-controlled recovery baseline must be verified before it is treated as the certified v1.5.0 source state.

Validate:

- [ ] `HEAD` resolves to the intended recovery source state.
- [ ] `release/v1.5.0` resolves to the certified release commit.
- [ ] `origin/release/v1.5.0` resolves to the certified release commit.
- [ ] `v1.5.0` resolves to the certified release commit.
- [ ] The `v1.5.0` release tag remains an annotated Git tag.
- [ ] Runtime-generated data, backups, logs, secrets, and environment-specific state have not been substituted for version-controlled release source.

Verification commands include:

`git rev-parse HEAD`

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

`git cat-file -t v1.5.0`

The certified release commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

### 22.3 PostgreSQL Backup Validation

PostgreSQL backup recovery evidence is stored under:

`/opt/wzi/backups/postgres`

The controlled backup implementation is:

`scripts/postgres-backup.sh`

Before using a backup as a recovery point, validate:

- [ ] The backup root exists.
- [ ] The intended backup set exists.
- [ ] The intended backup timestamp is appropriate for the recovery objective.
- [ ] Required database dump files are present.
- [ ] Required dump files are non-empty.
- [ ] The backup manifest is present where expected.
- [ ] SHA-256 sidecar files are present where expected.
- [ ] Backup age is acceptable for the intended recovery.
- [ ] The selected backup is documented as the recovery point.

The standard operational backup-health check is:

`./scripts/monitoring/backup-health.sh`

A healthy backup-monitor result provides operational evidence that the current backup set exists, is sufficiently fresh, contains files, and has non-zero size.

Backup-health success alone must not be interpreted as proof that a database restore has succeeded.

### 22.4 Controlled Restore Validation

Where PostgreSQL data is restored, the restore must be performed through a controlled recovery procedure.

Validate:

- [ ] The selected dump belongs to the intended database.
- [ ] The selected dump belongs to the intended recovery point.
- [ ] Restore activity does not silently overwrite production data without an approved recovery decision.
- [ ] The restore command completes successfully.
- [ ] The restored database is accessible.
- [ ] Required application databases are present.
- [ ] Required application data is available after restoration.
- [ ] The restore result is recorded as recovery evidence.

A backup file is not considered fully restore-certified solely because it exists or because backup-health reports `HEALTHY`.

Successful restore validation requires evidence from an actual controlled restore and subsequent application and health validation.

### 22.5 Core Service Recovery Validation

After the required source, configuration, and data recovery steps are complete, validate the core service layer.

Confirm:

- [ ] Docker is operational.
- [ ] PostgreSQL is running and healthy.
- [ ] Redis is running and healthy.
- [ ] n8n is running and healthy.
- [ ] Caddy is running.
- [ ] Dashboard is running and healthy.
- [ ] Unexpected container restart counts have been investigated.
- [ ] Required internal service dependencies are reachable.

Service-specific monitors should be used where applicable before the consolidated stack validation.

### 22.6 Reverse Proxy, TLS, and Application Validation

Validate the externally exposed and application-facing recovery path.

Confirm:

- [ ] Caddy health validation passes.
- [ ] Required HTTP or HTTPS endpoints respond as expected.
- [ ] TLS/SSL certificate validation passes.
- [ ] n8n health validation passes.
- [ ] Dashboard frontend responds successfully.
- [ ] Dashboard monitoring API responds successfully.
- [ ] Dashboard historical API responds successfully.
- [ ] Required API responses satisfy their expected contracts.

A running reverse-proxy container alone is not sufficient evidence that the application-facing recovery path is healthy.

### 22.7 Monitoring and Telemetry Recovery Validation

Operational observability must also recover successfully.

Confirm:

- [ ] Live telemetry generation is operating.
- [ ] Live telemetry is fresh.
- [ ] Historical telemetry generation is operating.
- [ ] Historical telemetry is fresh.
- [ ] Telemetry exporter timer is active.
- [ ] Telemetry exporter timer is enabled.
- [ ] Historical exporter timer is active.
- [ ] Historical exporter timer is enabled.
- [ ] Dashboard telemetry exposure remains read-only.
- [ ] Telemetry Growth monitor is healthy.
- [ ] Dashboard health monitor reports `HEALTHY`.

Run:

`./scripts/monitoring/dashboard-health.sh`

The command must return successful exit status in addition to displaying a healthy result.

### 22.8 Backup and Automation Recovery Validation

Confirm that automated operational controls required after recovery are restored.

Validate:

- [ ] PostgreSQL backup automation is available.
- [ ] PostgreSQL backup timer is active or otherwise in its intended operational state.
- [ ] PostgreSQL backup timer is enabled where required.
- [ ] Backup-health validation returns an acceptable result.
- [ ] Telemetry automation is operating.
- [ ] Historical telemetry automation is operating.
- [ ] Retention automation remains subject to the backup-health safety gate.
- [ ] Destructive telemetry retention is not forced while backup-health validation is failing.

The controlled PostgreSQL backup units are:

- `systemd/wzi-postgres-backup.service`
- `systemd/wzi-postgres-backup.timer`

Backup retention and telemetry retention are separate controls and must remain independently recoverable and auditable.

### 22.9 Consolidated Post-Recovery Validation

After individual recovery checks pass, run the consolidated health monitor:

`./scripts/monitoring/monitor-all.sh`

The certified v1.5.0 healthy baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

The ten controlled monitors are:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

The recovery must not be treated as complete while mandatory monitors remain in an unacceptable state.

### 22.10 Recovery Evidence Checklist

Preserve sufficient evidence to establish what was recovered and how recovery was validated.

Record:

- [ ] Incident or recovery identifier.
- [ ] Recovery date and time.
- [ ] Recovery operator.
- [ ] Recovery scope.
- [ ] Certified Git release baseline used.
- [ ] Recovery commit or tag used.
- [ ] Backup set used, where applicable.
- [ ] Backup timestamp.
- [ ] Database restore result, where applicable.
- [ ] Service recovery results.
- [ ] Dashboard validation result.
- [ ] Backup-health result.
- [ ] Consolidated monitoring result.
- [ ] Relevant command exit statuses.
- [ ] Deviations, warnings, or unresolved issues.
- [ ] Final recovery acceptance decision.

Runtime logs and mutable state may support recovery evidence but do not replace the frozen Git baseline, controlled backup evidence, or documented validation result.

### 22.11 Recovery Acceptance Criteria

Recovery may be accepted when all applicable mandatory criteria are satisfied:

1. The intended certified source baseline has been established.
2. Protected configuration required by the recovered environment is available.
3. Required database recovery has completed successfully where restoration was necessary.
4. Required application data is accessible.
5. Core services are operational.
6. Application-facing endpoints respond correctly.
7. TLS/SSL validation passes.
8. Live telemetry is fresh.
9. Historical telemetry is fresh.
10. Required operational timers and automation are in their intended state.
11. Backup health is acceptable.
12. Dashboard health is `HEALTHY`.
13. Consolidated monitoring reports the acceptable release baseline.
14. Required validation commands return successful exit status.
15. Recovery evidence has been preserved.
16. No unresolved critical condition remains.

If a mandatory criterion fails, recovery remains incomplete until the condition is corrected, formally accepted as an approved exception, or escalated through the applicable incident and change-control process.

### 22.12 Recovery Validation Principle

Recovery certification is evidence-based.

The frozen Git release baseline establishes the version-controlled system state. Protected environment configuration restores environment-specific settings and credentials. Database backups provide the recoverable data source. Runtime validation establishes whether the recovered environment is functioning correctly.

These evidence types are complementary and must not be substituted for one another.

A backup is not restore evidence until a controlled restore has been successfully demonstrated. A running container is not service-health evidence until the applicable health checks pass. A healthy-looking monitor message is not complete automation evidence unless the command also returns the expected exit status.

Recovery is complete only when the intended recovery point has been restored, required services and data have been validated, the operational health baseline is acceptable, and sufficient evidence has been retained for review and audit.
## 23. Daily Operations Checklist

Daily operations provide a concise operational review of WZI Core Stack and are intended to detect service degradation, stale telemetry, backup failure, certificate issues, automation failure, and unexpected release-state drift before they become larger incidents.

Daily review should rely on the established health monitors and automation state rather than on container-running status alone.

### 23.1 Daily Release and Repository Check

Confirm:

- [ ] The current repository is `/opt/wzi/core-stack`.
- [ ] The expected operational release baseline remains identifiable.
- [ ] Unexpected Git branch or release-reference drift has not occurred.
- [ ] Runtime-generated data, logs, backups, telemetry, and secrets remain outside Git.
- [ ] Unplanned working-tree changes are reviewed before operational changes are made.

For the certified v1.5.0 baseline, the release commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

Useful commands include:

`git branch --show-current`

`git status --short`

`git rev-parse HEAD`

Daily operations should not alter the frozen `v1.5.0` release tag.

### 23.2 Consolidated Health Check

Run:

`./scripts/monitoring/monitor-all.sh`

The expected healthy v1.5.0 baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

The consolidated monitor covers:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

If the consolidated monitor reports WARNING, CRITICAL, missing components, or a non-zero exit status, review the affected individual monitor before making corrective changes.

### 23.3 Dashboard and Telemetry Check

Run:

`./scripts/monitoring/dashboard-health.sh`

Confirm:

- [ ] Dashboard container exists.
- [ ] Dashboard container is running.
- [ ] Docker health is healthy.
- [ ] Unexpected restart count is not present.
- [ ] Dashboard frontend returns HTTP `200`.
- [ ] Expected dashboard page is detected.
- [ ] Monitoring API returns HTTP `200`.
- [ ] Monitoring API returns valid JSON.
- [ ] Monitoring API contract validates.
- [ ] Live telemetry is fresh.
- [ ] Historical API returns HTTP `200`.
- [ ] Historical API returns valid JSON.
- [ ] Historical API contract validates.
- [ ] Historical telemetry is fresh.
- [ ] Local Chart.js asset returns HTTP `200`.
- [ ] Live telemetry exporter timer is active and enabled.
- [ ] Historical exporter timer is active and enabled.
- [ ] Telemetry data mount remains read-only.
- [ ] Dashboard Overall Result is `HEALTHY`.
- [ ] Dashboard health command exits with status `0`.

A running dashboard container alone is not sufficient evidence of dashboard health.

### 23.4 PostgreSQL Backup Check

Run:

`./scripts/monitoring/backup-health.sh`

Confirm:

- [ ] Backup root exists.
- [ ] A current backup set exists.
- [ ] Backup age is within the accepted threshold.
- [ ] Backup directory is not empty.
- [ ] Backup size is non-zero.
- [ ] Backup health reports `HEALTHY`.
- [ ] Backup-health command exits with status `0`.

The PostgreSQL backup root is:

`/opt/wzi/backups/postgres`

The daily backup set should contain the required application database dumps and associated backup metadata generated by the approved backup process.

Backup health confirms operational backup availability and freshness. It does not replace restore testing.

### 23.5 Host Resource Check

Run:

`./scripts/monitoring/system-health.sh`

Review:

- [ ] CPU usage.
- [ ] Memory usage.
- [ ] Available memory.
- [ ] Root filesystem usage.
- [ ] Root filesystem free space.
- [ ] Inode usage.
- [ ] System load average.
- [ ] Host uptime.
- [ ] Docker engine availability.
- [ ] Running container count.
- [ ] Unhealthy container state.

The host-resource check should return:

`Overall Result: HEALTHY`

Unexpected resource growth or repeated threshold warnings should be investigated before they affect service availability.

### 23.6 TLS and SSL Check

Run:

`./scripts/monitoring/ssl-health.sh`

Confirm:

- [ ] TLS connection succeeds.
- [ ] Server certificate can be retrieved.
- [ ] Certificate trust validation passes.
- [ ] Hostname verification passes.
- [ ] Certificate validity period has started.
- [ ] Certificate has not expired.
- [ ] Remaining certificate lifetime is within the accepted monitoring threshold.
- [ ] SSL health result is `HEALTHY`.
- [ ] SSL monitor exits with status `0`.

TLS/SSL validation should be reviewed together with Caddy health when investigating externally exposed service issues.

### 23.7 Operational Timer Check

Daily operations should verify the required automation timers.

Review:

- [ ] `wzi-postgres-backup.timer`
- [ ] `wzi-dashboard-export.timer`
- [ ] `wzi-historical-export.timer`
- [ ] `wzi-telemetry-retention.timer`

For each timer, confirm:

- [ ] It is enabled where required.
- [ ] It is active.
- [ ] Its most recent execution is reasonable.
- [ ] Its next scheduled execution is reasonable.
- [ ] Its associated service is not repeatedly failing.

Useful commands include:

`systemctl list-timers --all --no-pager`

`systemctl is-enabled <timer>`

`systemctl is-active <timer>`

An enabled timer alone is not sufficient evidence that its associated automation is producing valid and fresh output.

### 23.8 Container and Service State Check

Review the current Docker service state.

Confirm:

- [ ] Caddy is running.
- [ ] Dashboard is running and healthy.
- [ ] n8n is running and healthy.
- [ ] PostgreSQL is running and healthy.
- [ ] Redis is running and healthy.
- [ ] No unexpected unhealthy containers are present.
- [ ] Unexpected restart activity is investigated.

Useful command:

`docker compose ps`

Container state should be interpreted together with the relevant service-specific health monitor.

### 23.9 Monitoring State and Logs Check

Review the current consolidated monitoring state and recent run evidence.

The overall monitoring state file is:

`/opt/wzi/core-stack/logs/state/overall-status.state`

Confirm:

- [ ] Current state is consistent with the latest consolidated monitor.
- [ ] Recent monitoring runs are being created under `logs/runs/`.
- [ ] No unexplained monitoring gaps are present.
- [ ] Critical or recovery state transitions are reviewed.
- [ ] Relevant detailed logs are preserved when investigating an incident.

Telegram notifications are an operational alerting channel and do not replace direct monitoring evidence.

### 23.10 Telemetry and Retention Safety Check

Confirm:

- [ ] Live telemetry remains fresh.
- [ ] Historical telemetry remains fresh.
- [ ] Telemetry growth monitor remains healthy.
- [ ] Dashboard storage remains read-only from the dashboard container.
- [ ] Historical retention automation is active.
- [ ] Retention remains protected by the PostgreSQL backup-health safety gate.
- [ ] Destructive retention is not forced when backup health is unacceptable.

PostgreSQL backup retention and historical telemetry retention are separate operational controls and should remain independently monitored.

### 23.11 Daily Exception Handling

If any daily check does not return the expected result:

1. Record the failing component and timestamp.
2. Run the affected individual monitor.
3. Review the relevant application, container, or systemd logs.
4. Avoid unrelated configuration changes.
5. Apply the smallest controlled corrective action.
6. Re-run the affected individual monitor.
7. Run `./scripts/monitoring/monitor-all.sh`.
8. Confirm the overall state has returned to an acceptable condition.
9. Preserve relevant incident and recovery evidence.
10. Escalate unresolved critical conditions through the applicable incident and change-control process.

A daily operational issue should not be considered resolved solely because a container has restarted or a process is running.

### 23.12 Daily Acceptance Criteria

The daily WZI Core Stack operational review may be accepted when all applicable mandatory conditions are satisfied:

- [ ] Consolidated monitoring is `HEALTHY`.
- [ ] Healthy count is `10`.
- [ ] Warning count is `0`.
- [ ] Critical count is `0`.
- [ ] Missing count is `0`.
- [ ] Consolidated monitor exits with status `0`.
- [ ] Dashboard health is `HEALTHY`.
- [ ] Dashboard health exits with status `0`.
- [ ] PostgreSQL backup health is `HEALTHY`.
- [ ] Backup-health monitor exits with status `0`.
- [ ] Host resources are within acceptable thresholds.
- [ ] SSL/TLS health is `HEALTHY`.
- [ ] Required automation timers are active and enabled.
- [ ] Live telemetry is fresh.
- [ ] Historical telemetry is fresh.
- [ ] No unexplained unhealthy containers are present.
- [ ] No unresolved critical operating condition remains.

Any unresolved critical result prevents the daily operational state from being classified as fully healthy.

### 23.13 Daily Operations Principle

Daily operations are evidence-based and should prioritize early detection over unnecessary intervention.

The consolidated monitor provides the primary daily operational health summary. Individual monitors provide component-level evidence when investigation is required. Automation timers provide evidence that scheduled operational processes remain enabled and active. Backup evidence protects recoverability, while dashboard and telemetry checks confirm that operational observability remains current.

The daily review should remain lightweight when the system is healthy and become more detailed only when evidence indicates a warning, critical condition, unexpected state transition, or operational anomaly.
## 24. Weekly Operations Checklist

The weekly WZI Core Stack operational review supplements the daily health checks with a broader examination of trends, automation history, backup continuity, telemetry growth, retention behavior, certificate horizon, monitoring evidence, and repository hygiene.

Weekly review should focus on patterns that may not be visible from a single healthy daily snapshot.

### 24.1 Weekly Consolidated Health Review

Run:

`./scripts/monitoring/monitor-all.sh`

Confirm:

- [ ] All ten controlled monitors execute.
- [ ] Healthy count is `10`.
- [ ] Warning count is `0`.
- [ ] Critical count is `0`.
- [ ] Missing count is `0`.
- [ ] Overall Result is `HEALTHY`.
- [ ] Consolidated monitor exits with status `0`.
- [ ] No repeated warning or critical pattern is evident from recent monitoring runs.
- [ ] Any previously observed abnormal state has documented follow-up.

The ten controlled monitors are:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

A healthy current result should be reviewed together with recent monitoring history when performing the weekly check.

### 24.2 Monitoring History Review

Review recent consolidated monitoring runs under:

`/opt/wzi/core-stack/logs/runs/`

Confirm:

- [ ] Monitoring runs have been created consistently.
- [ ] No unexplained monitoring gaps are present.
- [ ] WARNING or CRITICAL results have been investigated.
- [ ] RECOVERY transitions have corresponding incident follow-up where applicable.
- [ ] Repeated failures of the same component are identified as trends rather than isolated events.
- [ ] Relevant incident logs have been preserved.

The persisted consolidated state is stored at:

`/opt/wzi/core-stack/logs/state/overall-status.state`

The current persisted state should be consistent with the most recent consolidated monitor result.

### 24.3 PostgreSQL Backup Continuity Review

Review the PostgreSQL backup history under:

`/opt/wzi/backups/postgres`

Confirm:

- [ ] Recent scheduled backup sets exist.
- [ ] Backup generation has occurred consistently.
- [ ] No unexplained backup-day gaps are present.
- [ ] Required application database dumps are present.
- [ ] Backup dump files are non-empty.
- [ ] Backup manifests are present where expected.
- [ ] SHA-256 sidecar files are present where expected.
- [ ] Current backup health is `HEALTHY`.
- [ ] Backup-health command exits with status `0`.

Run:

`./scripts/monitoring/backup-health.sh`

The backup monitoring thresholds remain:

- Warning: `26 hours`
- Critical: `36 hours`

Weekly review should detect continuity problems that may not be obvious from examination of only the latest backup set.

Backup availability does not replace controlled restore testing.

### 24.4 Backup Automation Journal Review

Review recent execution evidence for:

`wzi-postgres-backup.service`

Useful command:

`journalctl -u wzi-postgres-backup.service --since "7 days ago" --no-pager`

Confirm:

- [ ] Scheduled backup service executions are present.
- [ ] Expected application databases are being selected.
- [ ] `n8n` backup completes successfully.
- [ ] `wzi_saas` backup completes successfully.
- [ ] Successful backup-set paths are recorded.
- [ ] No unexplained service failures are present.
- [ ] Backup retention behavior has not removed required current recovery points.

The PostgreSQL backup timer is:

`wzi-postgres-backup.timer`

Confirm that it remains enabled and active.

### 24.5 Historical Telemetry Growth Review

Run:

`./scripts/monitoring/telemetry-growth.sh`

Confirm:

- [ ] Telemetry Growth reports `HEALTHY`.
- [ ] Telemetry Growth command exits with status `0`.
- [ ] Historical database growth remains within an acceptable operating range.
- [ ] Sudden or unexplained growth is investigated.
- [ ] Collection frequency has not changed unexpectedly.
- [ ] Retention duration has not changed without controlled approval.
- [ ] Historical schema changes have not introduced uncontrolled growth.

The principal operational history tables are:

- `operations.telemetry_runs`
- `operations.service_health`
- `operations.host_metrics`
- `operations.backup_history`
- `operations.ssl_history`

Weekly growth review should consider both table size and row-count direction rather than relying only on total database size.

### 24.6 Historical Telemetry and Dashboard Trend Review

Run:

`./scripts/monitoring/dashboard-health.sh`

Review the historical dashboard and telemetry path.

Confirm:

- [ ] Dashboard health is `HEALTHY`.
- [ ] Live telemetry is fresh.
- [ ] Historical telemetry is fresh.
- [ ] Historical API contract remains valid.
- [ ] Historical exporter timer remains active and enabled.
- [ ] Dashboard exporter timer remains active and enabled.
- [ ] Telemetry data mount remains read-only.
- [ ] Historical service availability does not show unexplained degradation.
- [ ] Host resource trends do not show abnormal growth.
- [ ] Backup-age trends remain acceptable.
- [ ] SSL-validity trends remain acceptable.

The v1.5.0 historical dashboard uses a default 24-hour view with 5-minute aggregation, while the underlying PostgreSQL operations schema provides longer-term historical evidence.

### 24.7 Historical Export Automation Review

Review recent execution evidence for:

`wzi-historical-export.service`

Useful command:

`journalctl -u wzi-historical-export.service --since "7 days ago" --no-pager`

Confirm:

- [ ] Historical JSON contract validation succeeds.
- [ ] Historical telemetry export completes successfully.
- [ ] Historical output is written to the expected runtime path.
- [ ] Returned historical points are being generated.
- [ ] Overall historical status is acceptable.
- [ ] Availability is reviewed for unexpected degradation.
- [ ] Expected service series remain represented.

Historical runtime output is written to:

`dashboard/storage/live/history.json`

This runtime file is operational state and must remain outside Git.

### 24.8 Dashboard Export Automation Review

Review recent execution evidence for:

`wzi-dashboard-export.service`

Useful command:

`journalctl -u wzi-dashboard-export.service --since "7 days ago" --no-pager`

Confirm:

- [ ] Dashboard snapshots are being generated.
- [ ] Live status output is written successfully.
- [ ] Historical telemetry writes complete successfully.
- [ ] No repeated exporter failures are present.
- [ ] Generated telemetry timestamps progress normally.

The live runtime status file is:

`dashboard/storage/live/status.json`

The dashboard-export timer must remain enabled and active.

### 24.9 Retention Automation Review

Review:

`wzi-telemetry-retention.service`

Useful command:

`journalctl -u wzi-telemetry-retention.service --since "7 days ago" --no-pager`

Confirm:

- [ ] Retention service executions are present.
- [ ] Retention operates in the approved controlled apply mode.
- [ ] Configured retention remains `90 days`.
- [ ] Expired-run results are reviewed.
- [ ] Retention results are reasonable for the current telemetry age.
- [ ] No unexpected deletion behavior is evident.
- [ ] Retention remains protected by backup-health verification.
- [ ] Destructive retention is not forced while backup health is unacceptable.

The retention timer must remain enabled and active.

PostgreSQL backup retention and historical telemetry retention remain separate controls.

### 24.10 Operational Timer Review

Review the following timers:

- `wzi-postgres-backup.timer`
- `wzi-dashboard-export.timer`
- `wzi-historical-export.timer`
- `wzi-telemetry-retention.timer`

For each timer, confirm:

- [ ] Timer is enabled.
- [ ] Timer is active.
- [ ] Last execution time is reasonable.
- [ ] Next execution time is reasonable.
- [ ] Associated service journal shows successful operation.
- [ ] Generated output is present and current where applicable.

Useful commands include:

`systemctl list-timers --all --no-pager`

`systemctl is-enabled <timer>`

`systemctl is-active <timer>`

Timer state must be reviewed together with actual service execution evidence.

### 24.11 Host Capacity Trend Review

Run:

`./scripts/monitoring/system-health.sh`

Review:

- [ ] CPU usage.
- [ ] Memory usage.
- [ ] Available memory.
- [ ] Root filesystem usage.
- [ ] Root filesystem free capacity.
- [ ] Root inode usage.
- [ ] Load average.
- [ ] Host uptime.
- [ ] Docker engine availability.
- [ ] Running container count.
- [ ] Unhealthy container count.

Compare current values with recent operational history where available.

Weekly review should identify gradual capacity pressure before thresholds become critical.

### 24.12 SSL Certificate Horizon Review

Run:

`./scripts/monitoring/ssl-health.sh`

Confirm:

- [ ] TLS connection succeeds.
- [ ] Certificate trust and hostname verification pass.
- [ ] Certificate validity period is active.
- [ ] Certificate expiration date is reviewed.
- [ ] Remaining validity remains acceptable.
- [ ] SSL monitor reports `HEALTHY`.
- [ ] SSL monitor exits with status `0`.

Weekly review should focus not only on whether the certificate is currently valid, but also on whether its expiry horizon is moving toward warning or critical thresholds.

Caddy health should also be reviewed if certificate or external-access anomalies are detected.

### 24.13 Repository and Release Hygiene Review

Review:

`git branch --show-current`

`git status --short`

`git log --oneline --decorate -12`

Confirm:

- [ ] The current documentation or operational branch is understood.
- [ ] Unexpected repository modifications are not present.
- [ ] Runtime data has not been accidentally added to version control.
- [ ] `.env` and protected credentials remain excluded.
- [ ] Backups remain outside Git.
- [ ] Monitoring runtime logs and state remain outside Git.
- [ ] Dashboard runtime telemetry remains outside Git.
- [ ] Safety copies are not treated as authoritative release source.
- [ ] Certified release identity remains available.

The certified v1.5.0 release commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

Weekly documentation work must not redefine the frozen release tag.

### 24.14 Weekly Exception and Trend Review

Review significant operational events from the previous week.

Confirm:

- [ ] Repeated WARNING conditions are identified.
- [ ] Repeated CRITICAL conditions are identified.
- [ ] RECOVERY events have corresponding root-cause follow-up where required.
- [ ] Repeated container restarts are investigated.
- [ ] Repeated backup anomalies are investigated.
- [ ] Repeated telemetry-staleness events are investigated.
- [ ] Repeated timer/service failures are investigated.
- [ ] Capacity trends requiring action are identified.
- [ ] Certificate-horizon concerns are identified.
- [ ] Unresolved incidents are carried forward into change or incident management.

Weekly review should convert recurring operational symptoms into controlled corrective actions rather than repeatedly treating them as isolated events.

### 24.15 Weekly Acceptance Criteria

The weekly operational review may be accepted when all applicable mandatory conditions are satisfied:

- [ ] Consolidated monitoring is `HEALTHY 10/0/0/0`.
- [ ] Consolidated monitor exits with status `0`.
- [ ] Backup health is `HEALTHY`.
- [ ] Backup continuity is acceptable.
- [ ] Telemetry Growth is `HEALTHY`.
- [ ] Dashboard and historical telemetry health are `HEALTHY`.
- [ ] Host resources remain within acceptable operating limits.
- [ ] SSL/TLS health is `HEALTHY`.
- [ ] Required operational timers are enabled and active.
- [ ] Recent timer-driven service execution is successful.
- [ ] Historical telemetry growth is understood and controlled.
- [ ] Retention automation remains backup-gated.
- [ ] No unexplained operational monitoring gaps exist.
- [ ] No unresolved critical weekly trend remains.
- [ ] Repository and release hygiene are acceptable.

Any unresolved critical condition or unexplained recurring failure prevents the weekly operational state from being treated as fully acceptable.

### 24.16 Weekly Operations Principle

Weekly operations are trend-oriented.

Daily checks establish whether the system is healthy now. Weekly checks establish whether the system has remained healthy over time and whether gradual risk is developing in backups, telemetry growth, storage capacity, automation execution, certificate validity, monitoring continuity, or repository hygiene.

The weekly review should use current health status, recent logs, automation history, historical telemetry, backup continuity, and repository state together. A single healthy snapshot must not override evidence of repeated failures, unexplained gaps, or deteriorating trends.
## 25. Monthly Operations Checklist

The monthly WZI Core Stack operational review provides a broader governance and capacity assessment beyond the daily and weekly checks.

Monthly operations focus on sustained health, backup inventory, telemetry growth, retention behavior, automation continuity, infrastructure capacity, certificate horizon, repository integrity, recovery readiness, and unresolved operational trends.

The monthly review should use verified operational evidence and must not infer health solely from the presence of running services or files.

### 25.1 Monthly Consolidated Health Review

Run:

`./scripts/monitoring/monitor-all.sh`

Confirm:

- [ ] All ten controlled monitors execute.
- [ ] Healthy count is `10`.
- [ ] Warning count is `0`.
- [ ] Critical count is `0`.
- [ ] Missing count is `0`.
- [ ] Overall Result is `HEALTHY`.
- [ ] Consolidated monitor exits with status `0`.
- [ ] No unresolved recurring warning or critical condition exists.
- [ ] Significant recovery events from the period have appropriate follow-up.

The controlled v1.5.0 monitoring set includes:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

The monthly review should consider current health together with the operational history accumulated during the period.

### 25.2 Thirty-Day Monitoring Evidence Review

Review consolidated monitoring evidence under:

`/opt/wzi/core-stack/logs/runs/`

Also review:

`/opt/wzi/core-stack/logs/state/overall-status.state`

Confirm:

- [ ] Monitoring evidence exists throughout the period.
- [ ] No unexplained long monitoring gaps are evident.
- [ ] WARNING events have been reviewed.
- [ ] CRITICAL events have been reviewed.
- [ ] RECOVERY events have appropriate follow-up.
- [ ] Repeated failures have been treated as trends rather than isolated incidents.
- [ ] Relevant incident evidence remains available where required.
- [ ] The persisted overall state agrees with the current operational state.

Monthly review should identify systemic or recurring weaknesses that may be less obvious in daily or weekly checks.

### 25.3 PostgreSQL Backup Inventory Review

Review the PostgreSQL backup root:

`/opt/wzi/backups/postgres`

Confirm:

- [ ] Backup sets are present.
- [ ] Recent scheduled backup continuity is acceptable.
- [ ] The latest backup passes backup-health validation.
- [ ] Required application database dumps remain present.
- [ ] Backup files are non-empty.
- [ ] Backup manifests are present where expected.
- [ ] SHA-256 sidecar files are present where expected.
- [ ] Backup storage consumption is reviewed.
- [ ] Unexpected growth in backup storage is investigated.
- [ ] Unexpected gaps or duplicate operational backup runs are understood.
- [ ] Backup retention behavior is consistent with the approved policy.

Run:

`./scripts/monitoring/backup-health.sh`

The configured PostgreSQL backup retention period is:

`14 days`

The backup monitoring thresholds are:

- Warning: `26 hours`
- Critical: `36 hours`

Backup inventory and freshness provide operational recovery evidence but do not replace controlled restore testing.

### 25.4 Backup Automation Continuity Review

Review 30-day execution evidence for:

`wzi-postgres-backup.service`

Useful command:

`journalctl -u wzi-postgres-backup.service --since "30 days ago" --no-pager`

Confirm:

- [ ] Recent backup service execution evidence exists.
- [ ] Scheduled backups continue to select the expected application databases.
- [ ] `n8n` backups complete successfully.
- [ ] `wzi_saas` backups complete successfully.
- [ ] Backup destination paths are recorded.
- [ ] Repeated backup failures are not present.
- [ ] Failed backup executions have documented follow-up.

Also confirm:

- [ ] `wzi-postgres-backup.timer` is enabled.
- [ ] `wzi-postgres-backup.timer` is active.

A healthy timer state must be supported by successful service execution and valid backup output.

### 25.5 Telemetry Growth and Capacity Review

Run:

`./scripts/monitoring/telemetry-growth.sh`

Confirm:

- [ ] Telemetry Growth reports `HEALTHY`.
- [ ] Telemetry Growth command exits with status `0`.
- [ ] Current telemetry database growth remains acceptable.
- [ ] Growth is compared with prior weekly or monthly observations where available.
- [ ] Unexpected acceleration in telemetry growth is investigated.
- [ ] Collection frequency has not changed without control.
- [ ] Historical schema growth remains understood.
- [ ] Retention configuration remains appropriate.

The monthly review should use the approved telemetry-growth monitor as the authoritative operational growth signal where direct database sizing evidence is unavailable.

### 25.6 Historical Telemetry Retention Review

The approved historical telemetry retention period is:

`90 days`

Review:

`wzi-telemetry-retention.service`

Useful command:

`journalctl -u wzi-telemetry-retention.service --since "30 days ago" --no-pager`

Confirm:

- [ ] Retention service execution evidence exists.
- [ ] Retention continues to operate in controlled apply mode.
- [ ] Retention remains configured for `90 days`.
- [ ] Expired telemetry results are reviewed.
- [ ] Unexpected deletion behavior is not evident.
- [ ] Backup-health verification remains a prerequisite for destructive retention.
- [ ] Destructive retention is not forced while backup health is unacceptable.
- [ ] Retention behavior remains separate from PostgreSQL backup retention.

Also confirm:

- [ ] `wzi-telemetry-retention.timer` is enabled.
- [ ] `wzi-telemetry-retention.timer` is active.

Retention controls must remain auditable and backup-gated.

### 25.7 Dashboard and Historical Observability Review

Run:

`./scripts/monitoring/dashboard-health.sh`

Confirm:

- [ ] Dashboard health reports `HEALTHY`.
- [ ] Dashboard health exits with status `0`.
- [ ] Dashboard container remains healthy.
- [ ] Frontend response is successful.
- [ ] Monitoring API remains valid.
- [ ] Historical API remains valid.
- [ ] Live telemetry is fresh.
- [ ] Historical telemetry is fresh.
- [ ] Chart.js asset remains available.
- [ ] Live telemetry exporter timer is active and enabled.
- [ ] Historical exporter timer is active and enabled.
- [ ] Telemetry data mount remains read-only.
- [ ] No persistent observability gaps have been identified during the period.

Historical observability should be reviewed for sustained service availability, backup-age behavior, host-resource behavior, and SSL-validity trends.

### 25.8 Dashboard Export Automation Review

Review 30-day execution evidence for:

`wzi-dashboard-export.service`

Useful command:

`journalctl -u wzi-dashboard-export.service --since "30 days ago" --no-pager`

Confirm:

- [ ] Dashboard export executions are present.
- [ ] Live status snapshots are being generated.
- [ ] Historical telemetry writes are completing successfully.
- [ ] Output timestamps progress normally.
- [ ] Repeated exporter failures are not present.
- [ ] Any significant exporter interruption has documented follow-up.

The live runtime output is:

`dashboard/storage/live/status.json`

Confirm that:

- [ ] `wzi-dashboard-export.timer` remains enabled.
- [ ] `wzi-dashboard-export.timer` remains active.

Runtime telemetry remains operational state and must remain outside Git.

### 25.9 Historical Export Automation Review

Review 30-day execution evidence for:

`wzi-historical-export.service`

Useful command:

`journalctl -u wzi-historical-export.service --since "30 days ago" --no-pager`

Confirm:

- [ ] Historical export execution evidence exists.
- [ ] Historical JSON contract validation succeeds.
- [ ] Historical output generation succeeds.
- [ ] Expected service series remain represented.
- [ ] Historical availability remains acceptable.
- [ ] Returned historical points continue to be generated.
- [ ] Persistent export anomalies have been investigated.

The runtime historical output is:

`dashboard/storage/live/history.json`

Confirm:

- [ ] `wzi-historical-export.timer` remains enabled.
- [ ] `wzi-historical-export.timer` remains active.

Historical output files remain runtime data and are not authoritative release source.

### 25.10 Operational Timer Governance Review

Review:

- `wzi-postgres-backup.timer`
- `wzi-dashboard-export.timer`
- `wzi-historical-export.timer`
- `wzi-telemetry-retention.timer`

For each timer, confirm:

- [ ] Timer remains enabled.
- [ ] Timer remains active.
- [ ] Associated service has execution evidence for the period.
- [ ] No unexplained recurring service failures are present.
- [ ] Generated output remains valid where applicable.
- [ ] Last and next execution schedules remain reasonable.

Useful commands include:

`systemctl list-timers --all --no-pager`

`systemctl is-enabled <timer>`

`systemctl is-active <timer>`

Timer health requires both scheduler state and successful resulting automation.

### 25.11 Host Infrastructure Capacity Review

Run:

`./scripts/monitoring/system-health.sh`

Review:

- [ ] CPU usage.
- [ ] Memory usage.
- [ ] Available memory.
- [ ] Root filesystem usage.
- [ ] Root filesystem free capacity.
- [ ] Inode usage.
- [ ] Load average.
- [ ] Host uptime.
- [ ] Docker engine availability.
- [ ] Running container count.
- [ ] Unhealthy container state.

Also review filesystem capacity with:

`df -h / /opt`

Monthly review should identify gradual infrastructure growth or resource pressure before it becomes an availability risk.

### 25.12 Docker Storage Review

Review Docker storage using:

`docker system df`

Assess:

- [ ] Image storage usage.
- [ ] Container writable-layer usage.
- [ ] Local volume usage.
- [ ] Build-cache usage.
- [ ] Reclaimable storage is understood.
- [ ] Unexpected Docker storage growth is investigated.
- [ ] No destructive Docker cleanup is performed without understanding service and recovery impact.

Reclaimable storage is not automatically unnecessary storage.

Cleanup actions must remain controlled and must not remove required images, volumes, recovery data, or active service state.

### 25.13 SSL Certificate Horizon Review

Run:

`./scripts/monitoring/ssl-health.sh`

Confirm:

- [ ] TLS connection succeeds.
- [ ] Server certificate is retrieved successfully.
- [ ] Certificate trust validation passes.
- [ ] Hostname verification passes.
- [ ] Certificate validity period is active.
- [ ] Certificate expiry date is reviewed.
- [ ] Remaining certificate lifetime remains acceptable.
- [ ] SSL monitor reports `HEALTHY`.
- [ ] SSL monitor exits with status `0`.

Monthly review should identify certificate-renewal risk before the certificate enters warning or critical expiry thresholds.

Caddy health should also be reviewed when certificate, DNS, or external-access anomalies are observed.

### 25.14 Recovery Readiness Review

Monthly operations should include a review of recovery readiness.

Confirm:

- [ ] The certified release baseline remains identifiable.
- [ ] Current backup health is acceptable.
- [ ] Recent backup sets exist.
- [ ] Required database dumps remain available.
- [ ] Backup manifests and checksum sidecars are present where expected.
- [ ] Recovery procedures remain documented.
- [ ] No known unresolved condition would prevent controlled recovery.
- [ ] Recovery evidence from previous restore exercises remains available where applicable.

A healthy backup does not by itself certify restore capability.

Restore certification requires evidence from a controlled restore and subsequent validation.

### 25.15 Repository and Release Integrity Review

Review:

`git branch --show-current`

`git status --short`

`git log --oneline --decorate -12`

For the certified v1.5.0 release baseline, verify:

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

Expected commit:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

Confirm:

- [ ] Certified release references remain available.
- [ ] The release tag remains an annotated Git tag.
- [ ] Unexpected source drift is not present.
- [ ] Runtime telemetry remains outside Git.
- [ ] Monitoring logs and runtime state remain outside Git.
- [ ] Backups remain outside Git.
- [ ] `.env` and credentials remain outside Git.
- [ ] Temporary and safety-copy artifacts are not treated as release source.
- [ ] Documentation work does not redefine the frozen release baseline.

### 25.16 Monthly Security and Runtime Separation Review

Confirm:

- [ ] Protected credentials remain environment-managed.
- [ ] `.env` remains excluded from version control.
- [ ] Runtime logs are not treated as release source.
- [ ] Runtime telemetry is not treated as release source.
- [ ] PostgreSQL backup data is not committed to Git.
- [ ] Dashboard live status data remains runtime-generated.
- [ ] Historical dashboard data remains runtime-generated.
- [ ] Dashboard telemetry exposure remains read-only.
- [ ] Sanitized dashboard APIs do not expose protected credentials.
- [ ] Unexpected repository files are investigated.

Monthly security review should verify continued separation between source, secrets, runtime state, backup data, and release evidence.

### 25.17 Monthly Exception and Risk Review

Review significant operational observations from the period.

Confirm:

- [ ] Repeated warnings are identified.
- [ ] Repeated critical conditions are identified.
- [ ] Recovery events have appropriate follow-up.
- [ ] Repeated backup anomalies are investigated.
- [ ] Repeated telemetry-staleness issues are investigated.
- [ ] Repeated exporter failures are investigated.
- [ ] Repeated timer/service failures are investigated.
- [ ] Capacity trends requiring corrective action are identified.
- [ ] Certificate-horizon risks are identified.
- [ ] Recovery-readiness gaps are identified.
- [ ] Repository or security deviations are identified.
- [ ] Unresolved issues are carried into incident or change control.

Recurring issues should produce controlled corrective action rather than remain recurring operational exceptions.

### 25.18 Monthly Acceptance Criteria

The monthly operational review may be accepted when all applicable mandatory conditions are satisfied:

- [ ] Consolidated monitoring is `HEALTHY 10/0/0/0`.
- [ ] Consolidated monitoring exits with status `0`.
- [ ] PostgreSQL backup health is `HEALTHY`.
- [ ] Backup inventory and continuity are acceptable.
- [ ] Telemetry Growth is `HEALTHY`.
- [ ] Historical retention remains `90 days`.
- [ ] Retention remains backup-gated.
- [ ] Dashboard and historical observability are `HEALTHY`.
- [ ] Required operational timers are enabled and active.
- [ ] Thirty-day automation evidence exists.
- [ ] Host capacity remains acceptable.
- [ ] Docker storage usage is understood.
- [ ] SSL/TLS health is `HEALTHY`.
- [ ] Recovery readiness is acceptable.
- [ ] Repository and release integrity are acceptable.
- [ ] Runtime and secret separation controls remain intact.
- [ ] No unresolved critical monthly risk remains.

Any unresolved critical operational, capacity, recovery, security, or governance condition prevents the monthly operating state from being classified as fully acceptable.

### 25.19 Monthly Operations Principle

Monthly operations are governance- and capacity-oriented.

Daily operations establish whether WZI Core Stack is healthy now. Weekly operations establish whether it has remained healthy over time. Monthly operations determine whether the operating model remains sustainable, recoverable, controlled, and aligned with the certified release baseline.

The monthly review should combine operational health, monitoring history, backup inventory, telemetry growth, retention behavior, automation execution, infrastructure capacity, Docker storage, certificate horizon, recovery readiness, repository integrity, and security separation.

A healthy current snapshot must not override evidence of recurring failures, unmanaged capacity growth, recovery gaps, repository drift, or weakening operational controls.
## 26. Change Control

Changes to WZI Core Stack must be performed through a controlled, evidence-based process that protects the certified release baseline, limits operational risk, preserves recovery capability, and requires post-change validation.

Change control applies to version-controlled source, infrastructure configuration, Docker Compose definitions, monitoring scripts, systemd units, database migrations, reverse-proxy configuration, dashboard source, automation, retention controls, security-sensitive configuration, and other operational components that may affect the certified system state.

The current governance files under `docs/governance/` are placeholders and do not presently contain substantive approval or authorization rules. Therefore this section records only the change-control requirements supported by the certified repository, Master SOP, release evidence, and operational validation framework.

### 26.1 Change Identification

Before making a change, identify:

- [ ] The component or subsystem affected.
- [ ] The reason for the change.
- [ ] The intended outcome.
- [ ] The expected operational impact.
- [ ] The affected version-controlled files.
- [ ] The affected runtime services or automation.
- [ ] Whether database schema or data may be affected.
- [ ] Whether externally exposed services may be affected.
- [ ] Whether recovery or rollback may be required.
- [ ] Whether the change is corrective, preventive, operational, release-related, documentation-related, or incident-driven.

Changes should be scoped as narrowly as practical.

Unrelated configuration changes should not be combined with incident remediation or corrective maintenance without a clear reason.

### 26.2 Certified Baseline Protection

The certified WZI Core Stack v1.5.0 release baseline is:

- Release: `v1.5.0`
- Release commit: `94edcbe81bf2d0c99f6b57601c349189cc0a866b`
- Release branch: `release/v1.5.0`
- Remote release branch: `origin/release/v1.5.0`

Before a controlled change, verify the relevant repository state.

Useful commands include:

`git branch --show-current`

`git status --short`

`git rev-parse HEAD`

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

The frozen `v1.5.0` release tag must not be silently redefined by later operational or documentation work.

### 26.3 Pre-Change Evidence

Before changing an operational component, record sufficient evidence of the current state.

Depending on the change, this may include:

- [ ] Current Git branch.
- [ ] Current Git working-tree state.
- [ ] Current release identity.
- [ ] Current service/container state.
- [ ] Current individual health-monitor result.
- [ ] Current consolidated health-monitor result.
- [ ] Current dashboard health result.
- [ ] Current backup-health result.
- [ ] Current host-resource result.
- [ ] Current SSL result.
- [ ] Current timer state.
- [ ] Relevant systemd journal output.
- [ ] Relevant Docker or application logs.
- [ ] Current telemetry freshness.
- [ ] Current backup recovery point.

Pre-change evidence provides the comparison baseline for post-change validation and rollback decisions.

### 26.4 Backup and Recovery Readiness

A change that may affect application data, database structure, configuration, or recoverability should verify recovery readiness before implementation.

Confirm as applicable:

- [ ] PostgreSQL backup root exists.
- [ ] A current backup set exists.
- [ ] Backup-health validation is acceptable.
- [ ] Required database dumps exist.
- [ ] Backup files are non-empty.
- [ ] Required manifests and checksum sidecars exist.
- [ ] The intended recovery point is understood.
- [ ] Recovery procedures remain available.
- [ ] The frozen release baseline remains available.

Run:

`./scripts/monitoring/backup-health.sh`

A healthy backup provides recovery evidence but does not by itself prove that a restore will succeed.

Restore certification requires an actual controlled restore and subsequent validation.

### 26.5 Source and Configuration Change Controls

Version-controlled changes should remain distinguishable from runtime-generated state.

Authoritative source may include:

- Docker Compose files
- monitoring scripts
- systemd service and timer definitions
- database migrations
- dashboard application source
- reverse-proxy configuration
- release documentation
- controlled SOP documentation

Runtime-generated data must remain outside source control.

Examples include:

- `.env`
- `logs/`
- `backups/`
- monitoring runtime state
- PostgreSQL runtime data
- Redis runtime data
- n8n runtime data
- `dashboard/storage/live/status.json`
- `dashboard/storage/live/history.json`

Credentials, secrets, encryption keys, and environment-specific protected configuration must not be committed as change evidence.

### 26.6 Safety Copies and Temporary Artifacts

Safety copies may be used during controlled implementation where appropriate.

Examples already recognized in repository governance include:

- `*.pre-*`
- local configuration backups
- pre-refactor copies
- temporary migration or implementation copies

Safety copies are temporary operational aids.

They must not be treated as authoritative release source or substitute for Git history, release tags, migrations, or controlled recovery evidence.

### 26.7 Database Change Control

Database changes must be controlled.

Where schema changes are required:

- [ ] The intended database is identified.
- [ ] The migration scope is understood.
- [ ] The change is represented by a version-controlled migration where applicable.
- [ ] A current backup is available before potentially destructive work.
- [ ] The migration execution result is recorded.
- [ ] Required schema objects are verified after execution.
- [ ] Application compatibility is validated.
- [ ] Monitoring and telemetry behavior is revalidated.

The release-controlled telemetry migrations include:

- `database/migrations/001_operations_telemetry.sql`
- `database/migrations/002_telemetry_idempotency.sql`

Manual schema changes that cannot be reproduced from controlled evidence should be avoided.

### 26.8 Docker and Service Configuration Changes

Changes to Docker Compose, containers, service configuration, or dependencies must be followed by service-specific validation.

Confirm:

- [ ] The intended service is affected.
- [ ] Unrelated services are not changed unnecessarily.
- [ ] Container configuration remains valid.
- [ ] Required protected environment configuration remains available.
- [ ] Service startup succeeds.
- [ ] Docker health is acceptable where configured.
- [ ] Unexpected restart counts are investigated.

After changing one service, validate that service before relying on the consolidated health result.

### 26.9 Caddy, Domain, and TLS Changes

Changes affecting Caddy, domain routing, TLS/SSL, or external service exposure require targeted validation.

Confirm as applicable:

- [ ] Caddy configuration is valid.
- [ ] Caddy is running.
- [ ] Expected HTTP or HTTPS endpoint responds.
- [ ] TLS connection succeeds.
- [ ] Certificate trust validation passes.
- [ ] Hostname verification passes.
- [ ] Certificate health remains acceptable.
- [ ] n8n remains reachable where applicable.
- [ ] Dashboard exposure remains within the intended design.

A reverse-proxy or TLS change is incomplete until the applicable service health checks succeed.

### 26.10 Monitoring and Automation Changes

Changes to monitoring scripts, exporter scripts, alerting, retention, or timer-driven automation must preserve expected health and exit-status semantics.

Confirm as applicable:

- [ ] Modified scripts pass syntax validation.
- [ ] The affected individual monitor executes successfully.
- [ ] Human-readable health output is correct.
- [ ] Exit status matches the displayed state.
- [ ] Required timers remain enabled.
- [ ] Required timers remain active.
- [ ] Associated services execute successfully.
- [ ] Runtime output remains fresh.
- [ ] Monitoring state persistence remains functional.
- [ ] Telegram alert behavior is not confused with direct health evidence.

An enabled timer alone is not sufficient evidence that its automation is producing valid output.

### 26.11 Telemetry and Retention Changes

Changes affecting telemetry collection, history, export, storage, or retention require specific safeguards.

Confirm:

- [ ] Live telemetry remains fresh.
- [ ] Historical telemetry remains fresh.
- [ ] Historical API contract remains valid.
- [ ] Telemetry Growth remains acceptable.
- [ ] Historical exporter remains operational.
- [ ] Dashboard exporter remains operational.
- [ ] Telemetry retention remains configured as intended.
- [ ] Retention remains protected by backup-health verification.
- [ ] Destructive retention is not forced when backup health is unacceptable.
- [ ] Dashboard telemetry exposure remains read-only.

The approved historical telemetry retention baseline is:

`90 days`

### 26.12 Controlled Implementation

During change implementation:

1. Apply only the intended change.
2. Avoid unrelated modifications.
3. Preserve evidence of significant commands or outcomes.
4. Stop if the observed result differs materially from the intended result.
5. Do not conceal failed commands with successful-looking output.
6. Preserve exit-status semantics.
7. Avoid destructive corrective actions until the failure domain is understood.
8. Preserve the ability to revert or recover where applicable.

The smallest effective corrective action is preferred over broad or speculative changes.

### 26.13 Rollback and Backout Principle

A change should not continue indefinitely when it is clearly causing unacceptable degradation.

Rollback or recovery should be considered when:

- [ ] The affected service cannot be restored to an acceptable state.
- [ ] Required health validation continues to fail.
- [ ] Data integrity is uncertain.
- [ ] TLS or external access remains broken.
- [ ] Monitoring or automation integrity is compromised.
- [ ] The intended change result cannot be verified.
- [ ] Continuing the change increases operational risk.

Rollback evidence may include:

- reverting version-controlled source
- restoring previously validated configuration
- restoring the intended controlled recovery point
- reapplying the frozen release baseline where appropriate

Rollback must itself be validated.

Returning files to a previous state without confirming service health does not complete rollback.

### 26.14 Post-Change Individual Validation

After a configuration, infrastructure, application, database, monitoring, or operational change, run the affected individual validation first.

Examples include:

`./scripts/monitoring/postgres-health.sh`

`./scripts/monitoring/redis-health.sh`

`./scripts/monitoring/n8n-health.sh`

`./scripts/monitoring/caddy-health.sh`

`./scripts/monitoring/dashboard-health.sh`

`./scripts/monitoring/backup-health.sh`

`./scripts/monitoring/system-health.sh`

`./scripts/monitoring/ssl-health.sh`

`./scripts/monitoring/telemetry-growth.sh`

The specific monitor used should match the changed component.

### 26.15 Consolidated Post-Change Validation

After the affected component passes individual validation, run:

`./scripts/monitoring/monitor-all.sh`

The certified v1.5.0 healthy baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

A change should not be treated as operationally complete until the consolidated result is acceptable.

A displayed `HEALTHY` state without successful command exit status is incomplete automation evidence.

### 26.16 Post-Change Dashboard and Observability Validation

When the change may affect dashboard, API delivery, telemetry, exporters, storage exposure, or dependencies, run:

`./scripts/monitoring/dashboard-health.sh`

Confirm:

- [ ] Dashboard health is `HEALTHY`.
- [ ] Dashboard health exits with status `0`.
- [ ] Frontend delivery succeeds.
- [ ] Monitoring API contract remains valid.
- [ ] Historical API contract remains valid.
- [ ] Live telemetry is fresh.
- [ ] Historical telemetry is fresh.
- [ ] Required exporter timers remain active and enabled.
- [ ] Telemetry data mount remains read-only.

Observability must remain trustworthy after the change.

### 26.17 Post-Change Evidence

Record sufficient evidence to establish the outcome of the change.

Evidence may include:

- [ ] Change scope.
- [ ] Date and time.
- [ ] Affected files.
- [ ] Affected services.
- [ ] Pre-change Git state.
- [ ] Post-change Git state.
- [ ] Backup or recovery point used.
- [ ] Individual validation results.
- [ ] Consolidated monitoring result.
- [ ] Dashboard validation result.
- [ ] Relevant exit statuses.
- [ ] Timer state.
- [ ] Relevant journal or log evidence.
- [ ] Rollback action where applicable.
- [ ] Remaining warnings, exceptions, or unresolved issues.

Runtime logs may support the evidence record but do not replace version-controlled source or the frozen release baseline.

### 26.18 Documentation and Release Evidence Updates

Where a controlled change affects documented behavior, the corresponding controlled documentation should be updated.

Depending on scope, this may include:

- Master SOP
- Evidence Index
- release notes
- operational procedures
- migration evidence
- monitoring documentation
- recovery procedures
- dashboard contract documentation

Documentation must describe the implemented and validated state rather than an intended state that was never successfully deployed.

Changes made after release freeze must not silently redefine the source represented by the existing annotated release tag.

### 26.19 Incident-Driven Changes

Incident remediation may require urgent operational changes, but urgency does not remove the requirement for evidence and validation.

For incident-driven changes:

1. Preserve available failure evidence.
2. Identify the smallest likely failure domain.
3. Apply the smallest controlled corrective action.
4. Run the affected individual monitor.
5. Run the consolidated health monitor.
6. Confirm the expected operational state is restored.
7. Preserve incident and recovery evidence.
8. Carry unresolved or recurring issues into the applicable operational or change-management process.

A restarted container or running process alone does not prove incident resolution.

### 26.20 Change Acceptance Criteria

A change may be accepted when all applicable mandatory criteria are satisfied:

- [ ] Change scope and intended outcome are understood.
- [ ] Pre-change evidence was captured where required.
- [ ] Recovery readiness was confirmed where required.
- [ ] Source and runtime separation was preserved.
- [ ] Protected credentials were not committed.
- [ ] Database changes are reproducible where applicable.
- [ ] The changed component passes individual validation.
- [ ] Consolidated monitoring is acceptable.
- [ ] Required validation commands return successful exit status.
- [ ] Dashboard and observability remain acceptable where applicable.
- [ ] Required operational timers remain in the intended state.
- [ ] No unresolved critical condition remains.
- [ ] Rollback or recovery was performed if required.
- [ ] Post-change evidence was preserved.
- [ ] Documentation was updated where required.
- [ ] The frozen release baseline was not silently redefined.

Failure of a mandatory criterion means the change remains incomplete, requires corrective action, rollback, recovery, or formal follow-up.

### 26.21 Governance Limitation

The repository currently contains the following governance files:

- `docs/governance/Certification.md`
- `docs/governance/DDS.md`
- `docs/governance/WRAB.md`
- `docs/governance/WZI-GOV-DCR-001.md`

At the time of this documentation consolidation, these files contain no substantive governance content.

Therefore this Section 26 does not assign approval authority, decision rights, emergency-change authority, review-board membership, change-request numbering, or formal approval workflow to those documents.

Such controls must not be assumed until they are explicitly defined in authoritative governance documentation.

### 26.22 Change Control Principle

Change control is evidence-based and validation-driven.

The certified Git baseline establishes the protected source reference. Pre-change evidence establishes the comparison point. Backup and recovery controls preserve recoverability. Controlled implementation limits operational risk. Individual health checks validate the directly affected component. Consolidated monitoring validates the wider stack. Documentation and post-change evidence preserve auditability.

A change is not complete merely because configuration was edited, a container restarted, a command returned without visible error, or a service appears to be running.

A controlled change is complete only when the intended result is verified, mandatory health checks pass, recovery capability remains acceptable, unresolved critical conditions are absent, and sufficient evidence exists to explain what changed and how the final state was validated.
## 27. Appendix A — Important Paths

This appendix identifies the principal WZI Core Stack paths used for source control, operations, monitoring, backup, telemetry, documentation, governance, and recovery.

Paths are grouped by function so authoritative source can remain distinguishable from runtime-generated state, protected configuration, backup data, and temporary or safety-copy artifacts.

### 27.1 Core Repository Root

Primary repository path:

`/opt/wzi/core-stack`

This is the working repository for the WZI Core Stack source, documentation, monitoring, dashboard, migrations, systemd unit definitions, and Compose configuration.

Important repository-relative paths in this appendix are interpreted relative to this root unless stated otherwise.

### 27.2 Core Compose Files

The controlled Compose configuration files are:

- `compose.yml`
- `compose.core.yml`
- `compose.apps.yml`
- `compose.proxy.yml`

These files define the controlled container composition used by the WZI Core Stack.

The file:

`docker-compose.postgres-only.yml`

exists locally but is excluded from authoritative release treatment by repository governance and must not be assumed to represent the certified full-stack deployment baseline.

### 27.3 Reverse Proxy Configuration

Authoritative reverse-proxy source:

`proxy/config/Caddyfile`

This file contains the version-controlled Caddy configuration used by the stack.

Caddy runtime data and logs under paths such as:

- `proxy/data/`
- `proxy/config-data/`
- `proxy/logs/`

are runtime state and remain outside Git.

### 27.4 Monitoring Script Paths

Primary monitoring directory:

`scripts/monitoring/`

Controlled monitoring scripts include:

- `scripts/monitoring/docker-health-check.sh`
- `scripts/monitoring/postgres-health.sh`
- `scripts/monitoring/redis-health.sh`
- `scripts/monitoring/n8n-health.sh`
- `scripts/monitoring/caddy-health.sh`
- `scripts/monitoring/dashboard-health.sh`
- `scripts/monitoring/system-health.sh`
- `scripts/monitoring/backup-health.sh`
- `scripts/monitoring/telemetry-growth.sh`
- `scripts/monitoring/ssl-health.sh`
- `scripts/monitoring/monitor-all.sh`

Monitoring configuration and supporting modules include:

- `scripts/monitoring/config.sh`
- `scripts/monitoring/telegram.sh`
- `scripts/monitoring/lib/common.sh`
- `scripts/monitoring/lib/logging.sh`
- `scripts/monitoring/lib/output.sh`
- `scripts/monitoring/lib/utils.sh`

### 27.5 Telemetry and Export Script Paths

Controlled telemetry/export scripts include:

- `scripts/monitoring/dashboard-export.sh`
- `scripts/monitoring/historical-export.sh`
- `scripts/monitoring/telemetry-history.sh`
- `scripts/monitoring/telemetry-retention.sh`
- `scripts/monitoring/telemetry-growth.sh`

These are version-controlled implementation paths.

Generated telemetry output is runtime data and is documented separately in this appendix.

### 27.6 PostgreSQL Backup Script and Wrapper Paths

Controlled backup script:

`scripts/postgres-backup.sh`

Controlled Compose wrapper:

`scripts/wzi-compose`

Within the repository, their absolute paths are:

`/opt/wzi/core-stack/scripts/postgres-backup.sh`

`/opt/wzi/core-stack/scripts/wzi-compose`

Operational references to backup execution must be distinguished from the repository source path when reviewing system-level deployment configuration.

### 27.7 systemd Unit Definition Paths

Controlled systemd unit definitions are stored under:

`systemd/`

The certified unit-definition inventory includes:

- `systemd/wzi-postgres-backup.service`
- `systemd/wzi-postgres-backup.timer`
- `systemd/wzi-dashboard-export.service`
- `systemd/wzi-dashboard-export.timer`
- `systemd/wzi-historical-export.service`
- `systemd/wzi-historical-export.timer`
- `systemd/wzi-telemetry-retention.service`
- `systemd/wzi-telemetry-retention.timer`

These files are version-controlled source definitions.

The live systemd unit installation location is system-managed and should not be confused with the repository copy.

### 27.8 Database Migration Paths

Controlled database migrations are located under:

`database/migrations/`

The v1.5.0 operations-telemetry migrations are:

- `database/migrations/001_operations_telemetry.sql`
- `database/migrations/002_telemetry_idempotency.sql`

These files provide reproducible schema-change evidence and are authoritative source artifacts.

### 27.9 Dashboard Source Paths

Principal dashboard source paths include:

- `dashboard/Dockerfile`
- `dashboard/README.md`
- `dashboard/public/index.php`
- `dashboard/public/api/status.php`
- `dashboard/public/api/history.php`
- `dashboard/public/assets/css/wzi-dashboard.css`
- `dashboard/public/assets/js/wzi-dashboard.js`
- `dashboard/public/assets/vendor/chartjs/chart.umd.min.js`
- `dashboard/docs/HISTORICAL-API-CONTRACT.md`

Supporting directories include:

- `dashboard/config/`
- `dashboard/docs/`
- `dashboard/services/`
- `dashboard/storage/`
- `dashboard/templates/`

Tracked `.gitkeep` files preserve required empty directory structure where applicable.

### 27.10 Dashboard Runtime Telemetry Paths

Dashboard runtime telemetry is stored under:

`dashboard/storage/live/`

Current runtime files include:

- `dashboard/storage/live/status.json`
- `dashboard/storage/live/history.json`

These files are generated operational state.

They are not authoritative release source and must remain outside Git.

The repository preserves:

`dashboard/storage/.gitkeep`

so the required storage structure can exist without tracking runtime telemetry.

### 27.11 Monitoring Logs and State Paths

Primary runtime monitoring log directory:

`/opt/wzi/core-stack/logs`

Per-run monitoring evidence:

`/opt/wzi/core-stack/logs/runs/`

Persisted consolidated health state:

`/opt/wzi/core-stack/logs/state/overall-status.state`

Monitoring logs and state are runtime evidence.

They support troubleshooting, validation, incident review, and operational history but do not replace version-controlled source.

### 27.12 PostgreSQL Backup Paths

Primary backup root:

`/opt/wzi/backups`

PostgreSQL backup root:

`/opt/wzi/backups/postgres`

Each timestamped backup set is stored beneath the PostgreSQL backup root.

A validated backup set may contain:

- `MANIFEST.txt`
- `n8n.dump`
- `n8n.dump.sha256`
- `wzi_saas.dump`
- `wzi_saas.dump.sha256`

Backup data is recovery evidence and must remain outside Git.

Timestamped backup directory names are runtime-generated and must not be hardcoded as permanent operational paths.

### 27.13 Documentation Paths

Primary documentation root:

`docs/`

Controlled documentation includes:

- `docs/README.md`
- `docs/architecture/WZI-CS-ARCH-001.md`
- `docs/deployment/WZI-CS-DEP-001.md`
- `docs/disaster-recovery/WZI-CS-DR-001.md`
- `docs/operations/WZI-CS-OPS-001.md`

Release documentation includes:

- `docs/releases/v1.1.0.md`
- `docs/releases/v1.2.0.md`
- `docs/releases/v1.5.0.md`

### 27.14 Master SOP and Evidence Index Paths

Master v1.5.0 SOP:

`docs/sop/WZI-Core-Stack-v1.5.0-Master-SOP.md`

v1.5.0 Documentation Evidence Index:

`docs/sop/v1.5.0-Evidence-Index.md`

These documents consolidate operational and release evidence but do not replace the certified Git release commit or annotated release tag as the version-controlled source baseline.

### 27.15 Governance Documentation Paths

Governance directory:

`docs/governance/`

Current governance files include:

- `docs/governance/Certification.md`
- `docs/governance/DDS.md`
- `docs/governance/Enterprise-Standards.md`
- `docs/governance/WRAB.md`
- `docs/governance/WZI-GOV-DCR-001.md`
- `docs/governance/WZI-GOV-EDLP-001.md`

At the certified documentation-consolidation state, the following files remain empty placeholders:

- `docs/governance/Certification.md`
- `docs/governance/DDS.md`
- `docs/governance/WRAB.md`
- `docs/governance/WZI-GOV-DCR-001.md`

Their paths are authoritative repository locations even though their substantive governance content has not yet been defined.

### 27.16 Protected Environment Configuration Path

Protected environment configuration:

`.env`

Repository-relative location:

`/opt/wzi/core-stack/.env`

This file contains environment-managed configuration and protected values.

It is not version-controlled and must remain excluded from Git.

The certified operational state confirms restrictive file permissions are applied to this file.

Credentials, secrets, tokens, passwords, and other protected environment values must not be reproduced in documentation evidence.

### 27.17 Git Exclusion-Control Path

Repository exclusion controls:

`.gitignore`

This file defines exclusion categories including:

- environment and secret files
- PostgreSQL runtime data
- Redis runtime data
- n8n runtime data
- Caddy runtime state and logs
- backup data
- monitoring logs and state
- dashboard runtime telemetry
- temporary files
- local safety-copy artifacts

`.gitignore` is an authoritative version-controlled governance control.

### 27.18 Non-Authoritative Safety-Copy Paths

Local safety copies and temporary artifacts may exist during controlled changes or documentation consolidation.

Observed patterns include:

- `compose.apps.yml.pre-dashboard-*`
- `config-backups/`
- `dashboard/public/*.pre-5f-e`
- `scripts/monitoring/*.pre-telegram`
- `scripts/monitoring/*.pre-history`
- `scripts/monitoring/*.pre-atomic*`
- `scripts/monitoring-pre-refactor-*/`
- `docs/sop/*.pre-*`

These paths are safety or historical aids.

They must not be treated as authoritative release source unless independently promoted through controlled version-control and release governance.

### 27.19 Local Runtime and Data Directories

Local repository-root directories may exist for runtime or operational purposes, including:

- `postgres/`
- `redis/`
- `n8n/`
- `proxy/`
- `monitoring/`
- `logs/`
- `backups/`
- `config-backups/`

The existence of a local directory does not mean its contents are authoritative source.

Version-controlled status and `.gitignore` controls determine whether a specific artifact belongs to the certified source baseline.

### 27.20 Path Classification Principle

Important WZI Core Stack paths fall into distinct classes:

1. Version-controlled authoritative source.
2. Protected configuration.
3. Runtime-generated operational state.
4. Monitoring logs and state.
5. Recovery and backup evidence.
6. Documentation and governance artifacts.
7. Temporary or safety-copy artifacts.

These classes must remain distinguishable.

A path being present on the server does not by itself make it authoritative source.

Git history defines the version-controlled release baseline. Runtime paths describe the deployed operating state. Backup paths preserve recovery evidence. Documentation paths record procedures and controls. Temporary and safety-copy paths remain non-authoritative unless explicitly promoted through controlled change and release processes.
## 28. Appendix B — Important Commands

This appendix provides the principal commands used to operate, inspect, validate, troubleshoot, recover, and govern the WZI Core Stack.

Commands should normally be executed from:

`/opt/wzi/core-stack`

unless the command is explicitly system-level or uses an absolute path.

Command output is runtime evidence. The command itself does not prove a healthy state unless its output and exit status satisfy the applicable acceptance criteria.

### 28.1 Repository Navigation

Change to the WZI Core Stack repository:

`cd /opt/wzi/core-stack`

Confirm the current directory:

`pwd`

List repository contents:

`ls -la`

These commands establish the working context before operational or documentation activity.

### 28.2 Current Git Branch and Working Tree

Show the current branch:

`git branch --show-current`

Review the working tree:

`git status --short`

Review recent history:

`git log --oneline --decorate -12`

These commands should be used before and after controlled source or documentation changes.

### 28.3 Certified Release Identity Commands

Verify the current repository HEAD:

`git rev-parse HEAD`

Verify the controlled release branch:

`git rev-parse release/v1.5.0`

Verify the remote release branch:

`git rev-parse origin/release/v1.5.0`

Verify the commit referenced by the release tag:

`git rev-list -n 1 v1.5.0`

Verify that the release tag is an annotated tag object:

`git cat-file -t v1.5.0`

The certified v1.5.0 release commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

The expected tag type is:

`tag`

### 28.4 Git File and Tag Inventory

List version-controlled files:

`git ls-files`

List release tags:

`git tag --list --sort=version:refname`

List local and remote branches:

`git branch -a --no-color`

These commands support repository hygiene, release review, and source-of-truth verification.

### 28.5 Docker Container State

Show Compose-managed container state:

`docker compose ps`

Show all running containers with names, status, and ports:

`docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`

Inspect a container:

`docker inspect <container>`

Review recent service logs:

`docker compose logs --tail=100 <service>`

These commands provide container-level evidence but do not replace application health validation.

### 28.6 WZI Compose Wrapper

Controlled Compose wrapper:

`./scripts/wzi-compose`

The wrapper should be preferred where the documented WZI operational procedure requires it.

The repository source path is:

`scripts/wzi-compose`

Its repository absolute path is:

`/opt/wzi/core-stack/scripts/wzi-compose`

### 28.7 Consolidated Health Validation

Run the complete WZI Core Stack health baseline:

`./scripts/monitoring/monitor-all.sh`

The certified v1.5.0 healthy result is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

The displayed health result and command exit status must both be reviewed.

### 28.8 Docker Health Validation

Run:

`./scripts/monitoring/docker-health-check.sh`

This command validates the controlled Docker container baseline, including container state, health where configured, and restart behavior.

### 28.9 PostgreSQL Health Validation

Run:

`./scripts/monitoring/postgres-health.sh`

This command validates PostgreSQL container state, application database availability, connectivity, database sizing evidence, and applicable backup-age controls.

### 28.10 Redis Health Validation

Run:

`./scripts/monitoring/redis-health.sh`

This command validates Redis container state, Docker health, restart count, PING response, and operational Redis information.

### 28.11 n8n Health Validation

Run:

`./scripts/monitoring/n8n-health.sh`

This command validates n8n container state, Docker health, restart count, application health endpoint, and response behavior.

### 28.12 Caddy Health Validation

Run:

`./scripts/monitoring/caddy-health.sh`

This command validates Caddy container state, restart count, HTTP/HTTPS response behavior, and applicable certificate information.

### 28.13 Dashboard Health Validation

Run:

`./scripts/monitoring/dashboard-health.sh`

This command validates:

- dashboard container existence and health
- frontend HTTP response
- monitoring API response and contract
- live telemetry freshness
- historical API response and contract
- historical telemetry freshness
- Chart.js asset availability
- dashboard exporter timer state
- historical exporter timer state
- read-only telemetry exposure

Successful dashboard validation requires:

`Overall Result: HEALTHY`

and exit status:

`0`

### 28.14 Host Resource Validation

Run:

`./scripts/monitoring/system-health.sh`

This command validates host-level operational conditions including:

- memory
- disk
- inode usage
- load average
- uptime
- Docker engine availability
- container count
- unhealthy container state

### 28.15 PostgreSQL Backup Health Validation

Run:

`./scripts/monitoring/backup-health.sh`

This command validates:

- backup-root availability
- latest backup selection
- backup age
- expected backup-file count
- backup-set size
- overall backup health

A healthy backup result is recovery evidence but is not proof of successful restore capability.

### 28.16 Telemetry Growth Validation

Run:

`./scripts/monitoring/telemetry-growth.sh`

This command provides the approved operational telemetry-growth signal.

The expected healthy result is:

`Overall Result: HEALTHY`

with exit status:

`0`

### 28.17 SSL/TLS Health Validation

Run:

`./scripts/monitoring/ssl-health.sh`

This command validates:

- TLS connectivity
- certificate retrieval
- trust validation
- hostname validation
- validity period
- certificate-expiry status

The command must return a healthy result and successful exit status.

### 28.18 Operational Timer Inventory

List timers:

`systemctl list-timers --all --no-pager`

Check whether a timer is enabled:

`systemctl is-enabled <timer>`

Check whether a timer is active:

`systemctl is-active <timer>`

These commands are used for:

- `wzi-postgres-backup.timer`
- `wzi-dashboard-export.timer`
- `wzi-historical-export.timer`
- `wzi-telemetry-retention.timer`

An active and enabled timer does not by itself prove that the associated service is completing successfully.

### 28.19 systemd Service Journal Review

Review a service journal:

`journalctl -u <service> --no-pager`

Review recent weekly evidence:

`journalctl -u <service> --since "7 days ago" --no-pager`

Review recent monthly evidence:

`journalctl -u <service> --since "30 days ago" --no-pager`

Principal automated services include:

- `wzi-postgres-backup.service`
- `wzi-dashboard-export.service`
- `wzi-historical-export.service`
- `wzi-telemetry-retention.service`

### 28.20 PostgreSQL Backup Automation Journal

Weekly review:

`journalctl -u wzi-postgres-backup.service --since "7 days ago" --no-pager`

Monthly review:

`journalctl -u wzi-postgres-backup.service --since "30 days ago" --no-pager`

These commands provide execution-history evidence for scheduled PostgreSQL backups.

### 28.21 Dashboard Export Journal

Weekly review:

`journalctl -u wzi-dashboard-export.service --since "7 days ago" --no-pager`

Monthly review:

`journalctl -u wzi-dashboard-export.service --since "30 days ago" --no-pager`

These commands provide execution evidence for live dashboard telemetry export.

### 28.22 Historical Export Journal

Weekly review:

`journalctl -u wzi-historical-export.service --since "7 days ago" --no-pager`

Monthly review:

`journalctl -u wzi-historical-export.service --since "30 days ago" --no-pager`

These commands provide execution evidence for historical dashboard telemetry generation.

### 28.23 Telemetry Retention Journal

Weekly review:

`journalctl -u wzi-telemetry-retention.service --since "7 days ago" --no-pager`

Monthly review:

`journalctl -u wzi-telemetry-retention.service --since "30 days ago" --no-pager`

These commands provide execution evidence for the controlled telemetry-retention process.

### 28.24 Filesystem Capacity Review

Review root and `/opt` filesystem usage:

`df -h / /opt`

If the host does not support both targets in one invocation, use:

`df -h /`

Filesystem-capacity review supports proactive detection of disk-pressure risk.

### 28.25 Backup Storage Consumption

Review PostgreSQL backup storage:

`du -sh /opt/wzi/backups/postgres`

Review available timestamped backup directories:

`find /opt/wzi/backups/postgres -mindepth 1 -maxdepth 1 -type d`

These commands provide backup inventory and storage-consumption evidence.

Timestamped backup paths are runtime-generated and should not be hardcoded into permanent procedures.

### 28.26 Docker Storage Review

Run:

`docker system df`

This command reports:

- image storage
- container writable-layer storage
- local volume storage
- build-cache storage
- reclaimable storage

Reclaimable storage must not be deleted automatically without understanding operational and recovery impact.

### 28.27 Backup Script

Controlled PostgreSQL backup script:

`./scripts/postgres-backup.sh`

Repository source path:

`scripts/postgres-backup.sh`

The backup script should be executed according to the controlled operational procedure.

Manual backup execution must not be confused with proof that scheduled backup automation is healthy.

### 28.28 SHA-256 Evidence Commands

Generate a SHA-256 checksum:

`sha256sum <file>`

Compare recorded checksums before and after controlled documentation insertion or migration work.

Checksums provide evidence that validated temporary content exactly matches inserted or preserved content.

### 28.29 File Comparison Commands

Perform byte-for-byte comparison:

`cmp -s <file1> <file2>`

Show textual differences:

`diff -u <file1> <file2>`

These commands are used during documentation consolidation to verify that controlled insertion matches the validated temp file and that unaffected document regions remain unchanged.

### 28.30 Shell Syntax Validation

Validate a shell script without executing it:

`bash -n <script>`

This command should be used after modifying shell scripts and before runtime execution.

A syntax pass does not replace functional health validation.

### 28.31 HTTP Inspection Commands

A simple HTTP status check may be performed with:

`curl -I <url>`

A response-body request may be performed with:

`curl <url>`

Where operational monitoring already provides controlled HTTP validation, the applicable health monitor should remain the preferred acceptance test.

Raw `curl` output is supporting diagnostic evidence rather than complete service-health certification.

### 28.32 TLS Inspection Commands

TLS inspection may be performed with OpenSSL tooling such as:

`openssl s_client -connect <host>:443 -servername <host>`

The controlled operational SSL acceptance test remains:

`./scripts/monitoring/ssl-health.sh`

Manual TLS inspection supports troubleshooting but does not replace the certified SSL monitor.

### 28.33 Runtime Log Review

Review recent Compose service logs:

`docker compose logs --tail=100 <service>`

Review a systemd-managed automation service:

`journalctl -u <service> --no-pager`

Logs should be used to identify the failure domain before applying corrective action.

### 28.34 Controlled Troubleshooting Sequence

A practical command sequence after detecting an operational issue is:

1. `git branch --show-current`
2. `git status --short`
3. `docker compose ps`
4. Run the affected individual health monitor.
5. Review `docker compose logs --tail=100 <service>` or the applicable `journalctl` output.
6. Apply the smallest controlled corrective action.
7. Re-run the individual monitor.
8. Run `./scripts/monitoring/monitor-all.sh`.

A running process or restarted container is not sufficient proof of recovery.

### 28.35 Post-Change Validation Commands

After a controlled change, run the affected individual monitor first.

Examples include:

- `./scripts/monitoring/postgres-health.sh`
- `./scripts/monitoring/redis-health.sh`
- `./scripts/monitoring/n8n-health.sh`
- `./scripts/monitoring/caddy-health.sh`
- `./scripts/monitoring/dashboard-health.sh`
- `./scripts/monitoring/backup-health.sh`
- `./scripts/monitoring/system-health.sh`
- `./scripts/monitoring/ssl-health.sh`
- `./scripts/monitoring/telemetry-growth.sh`

Then run:

`./scripts/monitoring/monitor-all.sh`

Post-change validation must inspect both output and exit status.

### 28.36 Command Safety Principle

Commands in this appendix fall into different operational classes:

1. Read-only inspection.
2. Health validation.
3. Log and journal review.
4. Backup or recovery operation.
5. Configuration or source modification.
6. Potentially destructive maintenance.

Inspection and validation commands are generally safe to execute during normal review.

Commands that modify configuration, delete data, change Docker state, perform restores, alter database schema, change systemd configuration, or remove storage must follow the controlled change and recovery procedures described elsewhere in this SOP.

A command should not be considered safe merely because it is familiar or commonly used.

The operator must understand the affected component, expected outcome, recovery capability, and required post-command validation before executing a state-changing or destructive command.
## 29. Appendix C — Service and Timer Inventory

This appendix records the certified WZI Core Stack v1.5.0 service, container, systemd service, and timer inventory. It distinguishes Compose-managed application services from supporting containers and timer-triggered operational automation.

### 29.1 Docker Compose Service Inventory

The certified Compose service inventory contains:

| Compose Service | Runtime Container |
|---|---|
| `caddy` | `wzi-caddy` |
| `dashboard` | `wzi-dashboard` |
| `n8n` | `wzi-n8n` |
| `postgres` | `wzi-postgres` |
| `redis` | `wzi-redis` |

Authoritative inventory command:

`docker compose config --services`

These five services constitute the Compose-managed WZI Core Stack v1.5.0 runtime.

### 29.2 Running Container Inventory

The certified running-container inventory contains:

| Container | Role |
|---|---|
| `wzi-dashboard` | WZI Operations Dashboard |
| `wzi-caddy` | Reverse proxy and TLS termination |
| `wzi-n8n` | n8n automation platform |
| `wzi-postgres` | PostgreSQL database |
| `wzi-redis` | Redis service |
| `portainer` | Supporting Docker administration interface |

`portainer` is present on the host but is not part of the five-service WZI Core Stack Compose inventory.

Runtime inventory command:

`docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'`

### 29.3 Container Restart Baseline

At the DC-14.1 authoritative extraction checkpoint, the following restart baseline was observed:

| Container | Restart Count |
|---|---:|
| `wzi-dashboard` | `0` |
| `wzi-caddy` | `0` |
| `wzi-n8n` | `0` |
| `wzi-postgres` | `0` |
| `wzi-redis` | `0` |
| `portainer` | `0` |

Unexpected restart-count growth must be investigated operationally.

### 29.4 Docker Health-State Interpretation

Docker health status at the authoritative extraction checkpoint was:

| Container | Docker Health |
|---|---|
| `wzi-dashboard` | `healthy` |
| `wzi-caddy` | `none` |
| `wzi-n8n` | `healthy` |
| `wzi-postgres` | `healthy` |
| `wzi-redis` | `healthy` |
| `portainer` | `none` |

A Docker health value of `none` means that the container does not expose a Docker healthcheck. It must not by itself be interpreted as an unhealthy service.

Caddy operational health is validated separately through the WZI monitoring framework.

### 29.5 systemd Automation Inventory

The repository contains the following WZI operational systemd definitions:

- `wzi-dashboard-export.service`
- `wzi-dashboard-export.timer`
- `wzi-historical-export.service`
- `wzi-historical-export.timer`
- `wzi-postgres-backup.service`
- `wzi-postgres-backup.timer`
- `wzi-telemetry-retention.service`
- `wzi-telemetry-retention.timer`

These definitions implement scheduled backup, dashboard export, historical export, and telemetry-retention operations.

### 29.6 PostgreSQL Backup Service

Unit:

`wzi-postgres-backup.service`

Purpose:

- execute the WZI PostgreSQL database backup process.

Live systemd execution path:

`/opt/wzi/scripts/postgres-backup.sh`

The service executes as:

- `User=wziadmin`
- `Group=wziadmin`

The service is timer-triggered and is not required to remain continuously active.

A normal idle state may therefore be:

- `ACTIVE=inactive`
- `SUBSTATE=dead`
- `RESULT=success`

### 29.7 PostgreSQL Backup Timer

Unit:

`wzi-postgres-backup.timer`

Certified schedule:

- `OnCalendar=*-*-* 02:15:00`
- `Persistent=true`

Operational requirement:

- `ENABLED=enabled`
- `ACTIVE=active`

The timer invokes:

`wzi-postgres-backup.service`

PostgreSQL backup health must also be validated using:

`./scripts/monitoring/backup-health.sh`

### 29.8 Dashboard Export Service

Unit:

`wzi-dashboard-export.service`

Description:

`WZI Dashboard Live Telemetry Exporter`

Execution context:

- `User=wziadmin`
- `WorkingDirectory=/opt/wzi/core-stack`
- `ExecStart=/opt/wzi/core-stack/scripts/monitoring/dashboard-export.sh`

The service produces the live telemetry consumed by the WZI Operations Dashboard.

### 29.9 Dashboard Export Timer

Unit:

`wzi-dashboard-export.timer`

Certified scheduling controls:

- `OnBootSec=30s`
- `OnUnitActiveSec=60s`
- `Persistent=true`
- `Unit=wzi-dashboard-export.service`

The timer schedules live dashboard telemetry export approximately once per minute after activation.

Operational requirement:

- `ENABLED=enabled`
- `ACTIVE=active`

### 29.10 Historical Export Service

Unit:

`wzi-historical-export.service`

Description:

`WZI Historical Dashboard Exporter`

Execution context:

- `User=wziadmin`
- `WorkingDirectory=/opt/wzi/core-stack`
- `ExecStart=/opt/wzi/core-stack/scripts/monitoring/historical-export.sh`

This service generates historical dashboard telemetry used by the historical API and chart interface.

### 29.11 Historical Export Timer

Unit:

`wzi-historical-export.timer`

Certified scheduling controls:

- `OnBootSec=2min`
- `OnUnitActiveSec=5min`
- `Persistent=true`
- `Unit=wzi-historical-export.service`

The timer schedules historical telemetry export approximately every five minutes.

Operational requirement:

- `ENABLED=enabled`
- `ACTIVE=active`

### 29.12 Telemetry Retention Service

Unit:

`wzi-telemetry-retention.service`

Description:

`WZI Historical Telemetry Retention`

Execution context:

- `User=wziadmin`
- `WorkingDirectory=/opt/wzi/core-stack`
- `ExecStart=/opt/wzi/core-stack/scripts/monitoring/telemetry-retention.sh --apply`

The service applies the certified historical telemetry retention process.

Retention remains subject to the backup-health safety controls documented elsewhere in this SOP.

### 29.13 Telemetry Retention Timer

Unit:

`wzi-telemetry-retention.timer`

Certified schedule:

- `OnCalendar=*-*-* 03:30:00`
- `Persistent=true`
- `Unit=wzi-telemetry-retention.service`

Operational requirement:

- `ENABLED=enabled`
- `ACTIVE=active`

### 29.14 Timer-Triggered Service State Principle

The four operational services are timer-triggered jobs rather than continuously running daemons.

Therefore, states such as:

- `ACTIVE=inactive`
- `SUBSTATE=dead`
- `RESULT=success`

may represent normal successful completion.

Service correctness must be assessed using the combination of:

- timer enabled state
- timer active state
- service result
- recent journal execution evidence
- associated health-monitor results

An inactive timer-triggered service must not automatically be classified as failed.

### 29.15 Operational Timer Baseline

The certified operational timer set is:

| Timer | Required Enabled State | Required Active State |
|---|---|---|
| `wzi-postgres-backup.timer` | `enabled` | `active` |
| `wzi-dashboard-export.timer` | `enabled` | `active` |
| `wzi-historical-export.timer` | `enabled` | `active` |
| `wzi-telemetry-retention.timer` | `enabled` | `active` |

Validation commands:

`systemctl is-enabled <timer>`

`systemctl is-active <timer>`

Timer inventory may be reviewed with:

`systemctl list-timers --all --no-pager`

### 29.16 Service Execution Evidence

Recent service execution must be verified through the system journal.

Examples:

`journalctl -u wzi-postgres-backup.service --since "7 days ago" --no-pager`

`journalctl -u wzi-dashboard-export.service --since "7 days ago" --no-pager`

`journalctl -u wzi-historical-export.service --since "7 days ago" --no-pager`

`journalctl -u wzi-telemetry-retention.service --since "7 days ago" --no-pager`

At the DC-14.1 extraction checkpoint, recent journal evidence existed for all four operational services.

Journal evidence complements timer state and health-monitor validation.

### 29.17 Monitoring Coverage

The certified monitoring framework validates the primary WZI runtime through:

`./scripts/monitoring/monitor-all.sh`

The consolidated monitor covers:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

The certified baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

### 29.18 Dashboard Automation Monitoring

Dashboard automation health is validated through:

`./scripts/monitoring/dashboard-health.sh`

The dashboard monitor validates, among other controls:

- dashboard container state
- Docker health
- restart count
- frontend availability
- monitoring API contract
- telemetry freshness
- historical API contract
- historical telemetry freshness
- Chart.js availability
- historical exporter timer state
- dashboard telemetry exporter timer state
- read-only telemetry-data mount

The expected result is:

`Overall Result: HEALTHY`

### 29.19 Backup Automation Monitoring

PostgreSQL backup operational health is validated through:

`./scripts/monitoring/backup-health.sh`

Validation includes:

- backup root availability
- latest backup detection
- backup age
- backup file presence
- backup size

The expected result is:

`Overall Result : HEALTHY`

### 29.20 Telemetry Growth Monitoring

Historical telemetry database growth is validated through:

`./scripts/monitoring/telemetry-growth.sh`

The monitor provides database-size and growth-health evidence.

The expected result is:

`Overall Result: HEALTHY`

### 29.21 SSL Monitoring

TLS certificate health is validated through:

`./scripts/monitoring/ssl-health.sh`

The monitor validates:

- TLS connectivity
- certificate retrieval
- certificate trust
- hostname verification
- certificate validity period

The expected result is:

`Overall Result: HEALTHY`

### 29.22 Service and Timer Inventory Acceptance Criteria

The WZI Core Stack v1.5.0 service and timer inventory is acceptable when all of the following are true:

- the five certified Compose services are present
- required WZI containers are running
- unexpected container restart counts are absent or investigated
- Docker healthchecked containers are healthy
- all four operational timers are enabled
- all four operational timers are active
- recent execution evidence exists for each timer-triggered service
- service results do not indicate failure
- dashboard telemetry export remains operational
- historical telemetry export remains operational
- PostgreSQL backup automation remains operational
- telemetry retention automation remains operational
- the consolidated health monitor returns `HEALTHY`
- the consolidated health monitor exits with status `0`

### 29.23 Service and Timer Inventory Principle

The service inventory must distinguish between continuously running application services and timer-triggered operational jobs.

Container presence alone does not establish application health, and an inactive timer-triggered service alone does not establish failure.

Operational acceptance is based on the combined evidence of runtime state, restart history, Docker health where defined, timer state, service result, journal execution history, and WZI health-monitor results.
## 30. Appendix D — Release Milestones

This appendix records the principal version-controlled WZI Core Stack release milestones leading to the certified v1.5.0 baseline.

Milestone descriptions are limited to evidence available from Git tags, Git history, release notes, the Master SOP, and the Documentation Evidence Index. Runtime state is not used to redefine a historical release milestone.

### 30.1 Release Milestone Governance

A release milestone is identified through the combination of:

- Git release tag
- release commit
- release branch where applicable
- release documentation where available
- documented implementation scope
- validation evidence

Historical milestone descriptions must not be expanded beyond the evidence preserved in the repository.

The current certified release baseline remains:

- Release: `v1.5.0`
- Release commit: `94edcbe81bf2d0c99f6b57601c349189cc0a866b`
- Release branch: `release/v1.5.0`
- Remote release branch: `origin/release/v1.5.0`

### 30.2 Release Tag Inventory

The repository contains the following release tags:

1. `v1.0.0`
2. `v1.1.0`
3. `v1.2.0`
4. `v1.3.0`
5. `v1.4.0`
6. `v1.5.0`

At the authoritative extraction checkpoint, each listed release reference was an annotated Git tag object.

Release-tag existence establishes a versioned repository checkpoint.

It does not by itself establish the complete operational or documentation scope of that release.

### 30.3 v1.0.0 Release Checkpoint

Git records:

- Tag: `v1.0.0`
- Commit: `48ce54a39e4f0f7b0af0b763125e6fc135bb25cc`

The DC-15.1 extraction confirms the existence of this annotated release tag.

The extracted release-note inventory does not contain a `docs/releases/v1.0.0.md` release note.

Therefore this appendix records `v1.0.0` as an established Git release checkpoint without assigning additional milestone scope that is not supported by the extracted documentation evidence.

### 30.4 v1.1.0 — Production Infrastructure Milestone

Release evidence identifies:

- Release: `v1.1.0`
- Tag commit: `94a348daa547ed69bd7bab03bef8a46c3a8b554c`
- Release note: `docs/releases/v1.1.0.md`
- Release date recorded in the release note: `2026-07-30`

The release note identifies this milestone as:

`Production Infrastructure v1.1.0`

and describes it as the first production-ready infrastructure milestone.

Extracted v1.1.0 evidence includes backup-related validation, including backup checksum verification.

Git history describes the corresponding milestone as:

`Infrastructure as Code v1.1 - Backup automation and systemd integration`

This milestone therefore establishes the documented production-infrastructure and backup-automation stage of the WZI Core Stack evolution.

### 30.5 v1.2.0 — Governance and Documentation Milestone

Git records:

- Release: `v1.2.0`
- Tag commit: `b2fad375d44b9866532ebd9968eaaf4df7a1598f`

The relevant Git-history entry is:

`Finalize WZI Governance Foundation and v1.2.0 documentation`

The repository also contains:

`docs/releases/v1.2.0.md`

However, the DC-15.1 release-note heading extraction returned no substantive milestone text from that file.

Accordingly, this appendix limits the v1.2.0 milestone description to the Governance Foundation and documentation scope directly established by Git history.

No additional release-note claims are inferred.

### 30.6 v1.3.0 — Health Monitoring Framework Milestone

Git records:

- Release: `v1.3.0`
- Tag commit: `17844a31fa35311fc9089114138b1b538b291ee1`
- Release branch: `release/v1.3.0`
- Remote release branch: `origin/release/v1.3.0`

The release history identifies:

`feat(monitoring): complete WZI Core Stack v1.3.0 health framework`

Preceding monitoring milestones include:

- monitoring framework with Docker, PostgreSQL, and Redis health checks
- Monitoring Milestone 2 with shared monitoring framework and Docker, PostgreSQL, Redis, and n8n monitors
- Monitoring Milestone 3 with consolidated `monitor-all` orchestration

The v1.3.0 milestone therefore represents the consolidation of the WZI Core Stack health-monitoring framework.

### 30.7 v1.4.0 — State-Aware Alerting Milestone

Git records:

- Release: `v1.4.0`
- Tag commit: `442df1206bff849c3b68aa86cee94b404305e7c9`
- Release branch: `release/v1.4.0`
- Remote release branch: `origin/release/v1.4.0`

The corresponding Git-history entry is:

`feat(alerting): add state-aware Telegram monitoring alerts`

This milestone extends the monitoring framework with state-aware operational alerting.

The alerting milestone is distinct from the later Enterprise Operations Dashboard and historical-observability release.

### 30.8 v1.5.0 — Enterprise Operations Dashboard and Historical Observability

Git records:

- Release: `v1.5.0`
- Release commit: `94edcbe81bf2d0c99f6b57601c349189cc0a866b`
- Release branch: `release/v1.5.0`
- Remote release branch: `origin/release/v1.5.0`
- Documentation branch: `docs/v1.5.0-master-sop`
- Release note: `docs/releases/v1.5.0.md`

The release history identifies:

`release: WZI Core Stack v1.5.0 enterprise operations dashboard and historical observability`

The release note identifies the release scope as:

`Enterprise Operations Dashboard & Historical Observability`

v1.5.0 introduces the dashboard, live telemetry delivery, historical operational telemetry, historical dashboard presentation, retention controls, and consolidated release validation documented throughout this SOP.

### 30.9 Milestone 5A — Dashboard Foundation

The v1.5.0 release note identifies:

`5A — Dashboard Foundation`

This milestone establishes the Enterprise Operations Dashboard foundation.

The corresponding Git history also records:

`feat(dashboard): establish v1.5.0 operations dashboard foundation`

The dashboard implementation is maintained under:

`dashboard/`

and forms the base for the later live and historical observability milestones.

### 30.10 Milestone 5B — Read-Only Live Monitoring API

The v1.5.0 release note identifies:

`5B — Read-Only Live Monitoring API`

The live dashboard API is implemented through:

`dashboard/public/api/status.php`

Its runtime telemetry source is generated rather than stored as authoritative source.

The dashboard exposure model remains read-only and operationally separated from administrative mutation.

### 30.11 Milestone 5C — Automated Live Telemetry Scheduling

The v1.5.0 release note identifies:

`5C — Automated Live Telemetry Scheduling`

Live dashboard telemetry is produced through:

`scripts/monitoring/dashboard-export.sh`

The automated service/timer pair is:

- `systemd/wzi-dashboard-export.service`
- `systemd/wzi-dashboard-export.timer`

The generated live dashboard state is stored in:

`dashboard/storage/live/status.json`

This runtime-generated file remains outside the authoritative Git source baseline.

### 30.12 Milestone 5D — Dashboard Health Monitor

The v1.5.0 release note identifies:

`5D — Dashboard Health Monitor`

Dashboard release health is validated through:

`./scripts/monitoring/dashboard-health.sh`

The health monitor validates the dashboard container, frontend, monitoring API, telemetry freshness, historical observability path, exporter automation, local chart dependency, and read-only telemetry exposure.

The dashboard is not considered healthy solely because its container is running.

### 30.13 Milestone 5E — Historical Telemetry Storage

The v1.5.0 release note identifies:

`5E — Historical Telemetry Storage`

The historical telemetry implementation includes the PostgreSQL operations schema and controlled migrations:

- `database/migrations/001_operations_telemetry.sql`
- `database/migrations/002_telemetry_idempotency.sql`

Historical telemetry ingestion includes idempotency protection and failure isolation.

Historical retention and backup controls are governed independently from live telemetry generation.

### 30.14 Milestone 5F — Historical Observability

The v1.5.0 release note identifies:

`5F — Historical Observability`

The milestone includes historical dashboard delivery and associated operational validation.

Documented components include:

- historical JSON contract version 1
- historical API contract monitoring
- historical freshness monitoring
- historical dashboard health monitoring
- backup-age trends
- locally delivered historical chart capability

The historical dashboard contract is documented at:

`dashboard/docs/HISTORICAL-API-CONTRACT.md`

The historical API is:

`dashboard/public/api/history.php`

The generated historical dashboard state is:

`dashboard/storage/live/history.json`

### 30.15 v1.5.0 Monitoring Baseline

The certified v1.5.0 monitoring set contains ten controlled checks:

1. Docker
2. PostgreSQL
3. Redis
4. n8n
5. Caddy
6. Dashboard
7. Host Resources
8. PostgreSQL Backup
9. Telemetry Growth
10. SSL Certificate

The certified healthy acceptance baseline is:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

This baseline forms part of the operational acceptance evidence for v1.5.0.

### 30.16 v1.5.0 Historical Data Governance Milestone

v1.5.0 establishes controlled historical telemetry governance.

Documented controls include:

- historical PostgreSQL telemetry storage
- sanitized JSON dashboard delivery
- historical exporter separation from live telemetry collection
- historical freshness monitoring
- database-growth monitoring
- explicit telemetry retention
- backup-gated destructive retention
- read-only dashboard telemetry exposure

The approved historical telemetry retention baseline is:

`90 days`

PostgreSQL backup retention remains a separate control.

### 30.17 v1.5.0 Operational Automation Milestone

v1.5.0 includes controlled operational automation for:

- PostgreSQL backup
- dashboard live telemetry export
- historical telemetry export
- telemetry retention

The associated timer set is:

- `wzi-postgres-backup.timer`
- `wzi-dashboard-export.timer`
- `wzi-historical-export.timer`
- `wzi-telemetry-retention.timer`

Operational automation must remain observable through timer state, service result, journal history, and applicable health-monitor evidence.

### 30.18 v1.5.0 Release Validation Milestone

The frozen v1.5.0 release identity is validated through:

`git rev-parse HEAD`

`git rev-parse release/v1.5.0`

`git rev-parse origin/release/v1.5.0`

`git rev-list -n 1 v1.5.0`

The expected commit is:

`94edcbe81bf2d0c99f6b57601c349189cc0a866b`

The release tag must remain an annotated tag.

Operational release validation additionally requires the certified runtime-health baseline.

### 30.19 Documentation Consolidation Milestone

Post-release documentation consolidation is performed on:

`docs/v1.5.0-master-sop`

The Master SOP is:

`docs/sop/WZI-Core-Stack-v1.5.0-Master-SOP.md`

The Documentation Evidence Index is:

`docs/sop/v1.5.0-Evidence-Index.md`

Documentation consolidation records and organizes the certified system but does not redefine the frozen `v1.5.0` source tag.

### 30.20 Release Milestone Evidence Hierarchy

Release milestones should be interpreted using the following evidence hierarchy:

1. Git tag and tag target.
2. Version-controlled Git history.
3. Release note where substantive release documentation exists.
4. Master SOP.
5. Documentation Evidence Index.
6. Runtime validation evidence.

Runtime validation establishes current operational health.

It must not rewrite historical Git release identity.

### 30.21 Release Milestone Principle

Each WZI Core Stack release represents a controlled evolution of the system.

The release history demonstrates progression from infrastructure and backup automation, through governance and monitoring, into state-aware alerting, and finally the v1.5.0 Enterprise Operations Dashboard and historical-observability platform.

Historical milestone descriptions must remain evidence-based.

A later documentation consolidation, runtime change, or operational observation must not silently redefine an earlier Git tag or release commit.
## 31. Appendix E — Known Issues and Resolved Defects

This appendix records known limitations, historical work items, explicitly supported remediation evidence, and defect-prevention controls relevant to the certified WZI Core Stack v1.5.0 baseline.

A condition is described as a resolved defect only when repository evidence supports both the underlying condition and its remediation. Preventive controls, safety-copy artifacts, troubleshooting guidance, and inferred historical problems are not automatically classified as resolved defects.

### 31.1 Evidence Classification Principle

Appendix E uses the following classifications:

1. **Resolved remediation** — repository evidence explicitly records corrective or cleanup action.
2. **Historical known work** — an earlier release explicitly identifies unfinished work, but the extracted evidence does not independently prove later closure.
3. **Current limitation** — the certified system or repository has a documented limitation that does not necessarily represent operational failure.
4. **Preventive control** — a control exists to prevent a defect or failure condition, but the evidence does not establish that the condition previously occurred as a production defect.
5. **Troubleshooting condition** — a possible operational failure domain documented for investigation rather than a confirmed current defect.

Safety-copy names, temporary artifacts, monitoring branches, or architectural controls must not by themselves be used to invent historical defects.

### 31.2 Current Certified Operational State

At the DC-16.1 authoritative extraction checkpoint, no current critical operating defect was identified by the certified health-monitoring baseline.

The consolidated result was:

- Healthy: `10`
- Warnings: `0`
- Critical: `0`
- Missing: `0`
- Overall Result: `HEALTHY`
- Exit status: `0`

The following current checks also completed successfully:

- Dashboard health
- PostgreSQL backup health
- Telemetry growth health
- SSL certificate health

The required WZI operational timers were enabled and active, and the timer-triggered services reported successful execution results.

A healthy current state does not prove that no historical defect ever existed. It establishes only that the monitored runtime currently satisfies the certified operational baseline.

### 31.3 Historical Known Work — PostgreSQL Restore Testing

The `v1.1.0` release note explicitly records:

`Known Work Remaining`

including:

`PostgreSQL restore testing`

This is valid historical release evidence.

The DC-16.1 extraction does not contain an explicit later Git fix commit or release-note statement that independently closes this specific historical work item.

Therefore Appendix E does not silently mark the v1.1.0 restore-testing item as resolved.

Current recovery governance requires actual controlled restore evidence.

The Master SOP states that backup-health success alone is not proof that a database restore has succeeded and that successful restore validation requires evidence from an actual controlled restore followed by application and health validation.

Accordingly, backup availability and backup-health status must remain distinguishable from restore certification.

### 31.4 Resolved Repository Remediation — Temporary Migration Artifacts

Git history explicitly records the `v1.0.0` tagged commit:

`48ce54a39e4f0f7b0af0b763125e6fc135bb25cc`

with the commit description:

`Remove temporary migration artifacts from repository`

This is direct repository remediation evidence.

Status:

**Resolved remediation**

The certified source baseline must continue to distinguish authoritative migrations from temporary migration artifacts and safety copies.

Version-controlled database changes belong under:

`database/migrations/`

Temporary implementation artifacts must not be treated as release source unless they are deliberately promoted through controlled change and validation.

### 31.5 Historical Telemetry Duplicate-Ingestion Control

Historical telemetry ingestion is protected by:

`database/migrations/002_telemetry_idempotency.sql`

The migration establishes the uniqueness control required to prevent duplicate telemetry runs for the same generated timestamp.

The Master SOP records that duplicate insertion attempts are rejected by PostgreSQL.

Classification:

**Preventive control**

The DC-16.1 extraction does not establish an explicit historical production incident in which duplicate telemetry rows caused a certified release defect.

Therefore the existence of the idempotency migration must not be rewritten as proof that a duplicate-ingestion defect previously occurred.

The idempotency control must remain intact when telemetry collection or historical-export automation is modified.

### 31.6 Historical Telemetry Atomicity and Failure Isolation

The v1.5.0 release evidence includes:

- idempotent historical ingestion
- atomic transaction handling
- failure-isolated telemetry writing

These controls strengthen historical telemetry reliability.

Historical write failure must not unnecessarily disable live telemetry generation.

Classification:

**Preventive and resilience controls**

The DC-16.1 extraction does not provide an explicit fix commit proving that atomicity or failure isolation was introduced to remediate a specifically documented production defect.

Accordingly, Appendix E records these as hardened design controls rather than invented historical defects.

### 31.7 Safety Copies and Pre-Change Artifacts

The repository and working environment contain safety and historical artifacts, including patterns such as:

- `dashboard/public/*.pre-5f-e`
- `scripts/monitoring/*.pre-telegram`
- `scripts/monitoring/*.pre-atomic*`
- documentation `.pre-dc*` files
- local configuration backup files

These files may provide implementation or recovery context.

They are not authoritative source merely because they exist.

Classification:

**Non-authoritative historical/safety artifacts**

A filename such as `pre-atomic`, `pre-telegram`, or `pre-5f-e` does not prove that the preceding implementation was defective.

Safety copies must not be promoted into release evidence without controlled review.

### 31.8 Governance Documentation Placeholder Limitation

The following governance files exist in the certified repository:

- `docs/governance/Certification.md`
- `docs/governance/DDS.md`
- `docs/governance/WRAB.md`
- `docs/governance/WZI-GOV-DCR-001.md`

At the DC-16.1 extraction checkpoint, each file was zero bytes and had SHA-256:

`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

Classification:

**Current documentation/governance limitation**

These placeholder files do not provide substantive approval authority, certification rules, decision rights, or release authorization procedures.

Operational change-control documentation in this Master SOP must therefore not imply that those placeholder files currently establish approval authority that they do not contain.

Future substantive governance content must be introduced through controlled documentation governance rather than inferred from empty filenames.

### 31.9 Docker Healthcheck Interpretation Limitation

Not every running container necessarily exposes a Docker-native healthcheck.

For the certified runtime, `wzi-caddy` may report Docker health as:

`none`

while remaining operationally healthy through the WZI Caddy monitoring controls.

Classification:

**Monitoring interpretation limitation**

A Docker health value of `none` does not by itself represent a service defect.

Likewise, a container being `running` does not by itself prove application health.

Applicable WZI health monitors must be used to determine operational acceptance.

### 31.10 Timer-Triggered Service State Interpretation

Timer-triggered operational services may normally appear as:

- `ACTIVE=inactive`
- `SUBSTATE=dead`
- `RESULT=success`

after successful completion.

This applies to scheduled jobs such as backup, dashboard export, historical export, and telemetry retention.

Classification:

**Operational interpretation limitation**

An inactive one-shot service must not automatically be classified as failed.

Correct validation uses:

- timer enabled state
- timer active state
- service result
- recent journal execution evidence
- generated-output freshness
- applicable WZI health-monitor result

### 31.11 Backup Health Does Not Equal Restore Certification

A PostgreSQL backup may be healthy while restore capability remains unproven for a specific recovery exercise.

Backup-health validation confirms operational characteristics including:

- backup-root availability
- latest backup detection
- backup age
- expected files
- non-zero backup size

It does not by itself prove that a restore operation has completed successfully.

Classification:

**Recovery evidence limitation**

Restore certification requires evidence from a controlled restore and subsequent validation.

This distinction must remain intact during disaster recovery, monthly recovery-readiness review, and release certification.

### 31.12 Runtime Files Are Not Release-Source Defects

Runtime-generated files include:

- `dashboard/storage/live/status.json`
- `dashboard/storage/live/history.json`
- monitoring runtime state
- logs
- backup data

These files are expected operational artifacts.

Their exclusion from Git is an intentional source/runtime separation control.

Classification:

**By-design runtime separation**

Runtime-generated files must not be classified as missing release-source files merely because Git does not track them.

Likewise, runtime files must not be committed solely to preserve documentation evidence.

### 31.13 Read-Only Dashboard Exposure

The dashboard telemetry path is intentionally read-only.

The v1.5.0 release baseline includes:

- read-only dashboard telemetry mount
- read-only live API
- read-only historical API
- sanitized historical JSON
- no PostgreSQL credentials exposed to dashboard PHP

Classification:

**Security design control**

The inability of the dashboard to modify telemetry source data is intentional and must not be treated as an application defect.

A writable telemetry mount would instead represent an operational control failure requiring investigation.

### 31.14 Retention Backup-Safety Constraint

Historical telemetry retention is protected by backup-health verification.

Destructive retention must not be forced while PostgreSQL backup health is unacceptable.

Classification:

**Safety constraint**

Retention refusal caused by an unacceptable backup state is intended protective behavior, not a retention defect.

The correct remediation is to investigate and restore acceptable backup health before destructive retention resumes.

PostgreSQL backup retention and historical telemetry retention remain separate controls.

### 31.15 Monitoring and Alerting Interpretation

Telegram alerting provides notification of meaningful monitoring-state transitions.

It is not the sole source of operational truth.

Alert suppression when the overall state remains unchanged is intentional state-aware behavior.

Classification:

**Alerting interpretation control**

Absence of a repeated Telegram alert does not prove absence of an operational condition.

Operational truth must be established through monitor output, exit status, detailed run logs, individual health checks, and service evidence.

### 31.16 Troubleshooting Conditions Are Not Current Defects

The Master SOP contains troubleshooting procedures for:

- Docker and container issues
- PostgreSQL and Redis issues
- n8n and Caddy issues
- dashboard and telemetry issues
- backup and retention issues
- SSL and certificate issues
- systemd automation issues

These troubleshooting categories describe potential failure domains.

They do not establish that each failure is currently present.

A condition should be classified as an active issue only when current evidence demonstrates the failure.

### 31.17 Incident Resolution Standard

A restarted container or running process alone does not prove incident resolution.

After remediation:

1. Re-run the affected individual health monitor.
2. Confirm the affected service or automation behaves correctly.
3. Run the consolidated monitor.
4. Verify expected exit-status semantics.
5. Preserve incident and recovery evidence.

An incident should not be classified as resolved until the expected operational state has been restored and the applicable validation criteria pass.

### 31.18 Explicit Fix-Commit Evidence Limitation

The DC-16.1 search for commits explicitly matching fix-oriented terminology returned no entries under:

`Git history — explicit fix commits`

This result does not prove that no corrective engineering work ever occurred.

It means that Appendix E must not invent specific historical defect/fix pairs based solely on current architecture, feature commits, safety-copy filenames, or later hardening controls.

The explicitly supported repository-remediation item identified by the broader Git-history extraction is the removal of temporary migration artifacts recorded at `v1.0.0`.

### 31.19 Current Critical-Issue Status

At the DC-16.1 authoritative extraction checkpoint:

- required containers were running
- required restart counts were `0`
- Docker-healthchecked core containers were healthy
- required operational timers were enabled and active
- timer-triggered services reported `RESULT=success`
- consolidated monitoring was `HEALTHY 10/0/0/0`
- dashboard health was `HEALTHY`
- PostgreSQL backup health was `HEALTHY`
- telemetry growth health was `HEALTHY`
- SSL health was `HEALTHY`

No current critical operating defect was identified by these certified checks.

This statement applies only to the monitored certification scope and extraction checkpoint.

It must not be interpreted as a guarantee that future defects cannot occur or that every possible application condition is monitored.

### 31.20 Issue Escalation and Carry-Forward

Repeated warnings, backup anomalies, telemetry-staleness events, exporter failures, timer/service failures, capacity risks, certificate-horizon risks, and other recurring operational anomalies must be investigated.

Unresolved or recurring issues should be carried into the applicable:

- incident process
- change-control process
- recovery process
- operational review

A recurring issue should produce controlled corrective action rather than remain indefinitely as an undocumented operational exception.

### 31.21 Defect and Limitation Acceptance Principle

Known issues, resolved defects, preventive controls, historical work items, and design limitations must remain distinguishable.

A current healthy runtime does not erase historical evidence.

A safety-copy filename does not prove a historical defect.

A preventive control does not prove that the prevented failure previously occurred.

A backup does not prove restore capability.

An inactive timer-triggered service does not prove automation failure.

A running container does not prove application health.

A notification does not replace direct monitoring evidence.

Appendix E must therefore remain evidence-based and conservative. Historical defects may be marked resolved only where sufficient evidence supports both the condition and its remediation.
