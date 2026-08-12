BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_telemetry_runs_generated_at_unique
ON operations.telemetry_runs (generated_at);

COMMIT;
