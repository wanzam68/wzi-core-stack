BEGIN;

CREATE SCHEMA IF NOT EXISTS operations;

-- =========================================================
-- Telemetry run
-- One record represents one dashboard-export snapshot.
-- =========================================================

CREATE TABLE IF NOT EXISTS operations.telemetry_runs (
    id              BIGSERIAL PRIMARY KEY,
    generated_at    TIMESTAMPTZ NOT NULL,
    environment     TEXT NOT NULL,
    release_version TEXT,
    overall_status  TEXT NOT NULL,
    latest_run      TEXT,
    branch          TEXT,
    commit_hash     TEXT,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT telemetry_runs_status_check
        CHECK (overall_status IN ('HEALTHY', 'WARNING', 'CRITICAL', 'UNKNOWN'))
);

-- =========================================================
-- Individual service health
-- =========================================================

CREATE TABLE IF NOT EXISTS operations.service_health (
    id              BIGSERIAL PRIMARY KEY,
    telemetry_run_id BIGINT NOT NULL
        REFERENCES operations.telemetry_runs(id)
        ON DELETE CASCADE,

    service_name    TEXT NOT NULL,
    status          TEXT NOT NULL,
    restart_count   INTEGER,

    CONSTRAINT service_health_status_check
        CHECK (status IN ('HEALTHY', 'WARNING', 'CRITICAL', 'UNKNOWN')),

    CONSTRAINT service_health_unique
        UNIQUE (telemetry_run_id, service_name)
);

-- =========================================================
-- Host resource telemetry
-- =========================================================

CREATE TABLE IF NOT EXISTS operations.host_metrics (
    id               BIGSERIAL PRIMARY KEY,
    telemetry_run_id BIGINT NOT NULL
        REFERENCES operations.telemetry_runs(id)
        ON DELETE CASCADE,

    cpu_percent      NUMERIC(5,2),
    memory_percent   NUMERIC(5,2),
    disk_percent     NUMERIC(5,2),
    disk_available   TEXT,

    load_1           NUMERIC(10,2),
    load_5           NUMERIC(10,2),
    load_15          NUMERIC(10,2),

    uptime           TEXT,

    CONSTRAINT host_metrics_run_unique
        UNIQUE (telemetry_run_id)
);

-- =========================================================
-- PostgreSQL backup history
-- =========================================================

CREATE TABLE IF NOT EXISTS operations.backup_history (
    id               BIGSERIAL PRIMARY KEY,
    telemetry_run_id BIGINT NOT NULL
        REFERENCES operations.telemetry_runs(id)
        ON DELETE CASCADE,

    status           TEXT NOT NULL,
    age_hours        INTEGER,
    backup_size      TEXT,

    CONSTRAINT backup_history_run_unique
        UNIQUE (telemetry_run_id)
);

-- =========================================================
-- SSL certificate history
-- =========================================================

CREATE TABLE IF NOT EXISTS operations.ssl_history (
    id               BIGSERIAL PRIMARY KEY,
    telemetry_run_id BIGINT NOT NULL
        REFERENCES operations.telemetry_runs(id)
        ON DELETE CASCADE,

    status           TEXT NOT NULL,
    hostname         TEXT,
    days_remaining   INTEGER,
    expires_at       TEXT,

    CONSTRAINT ssl_history_run_unique
        UNIQUE (telemetry_run_id)
);

-- =========================================================
-- Historical query indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_telemetry_runs_generated_at
    ON operations.telemetry_runs (generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_runs_status
    ON operations.telemetry_runs (overall_status);

CREATE INDEX IF NOT EXISTS idx_service_health_service
    ON operations.service_health (service_name);

CREATE INDEX IF NOT EXISTS idx_service_health_status
    ON operations.service_health (status);

COMMIT;
