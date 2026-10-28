-- Run as energia_forecast. Mirrors `spillway publish` (insert the model, a run in `loading`, the
-- hourly rows, flip the run to `ready`, move the `is_current` flag, purge old runs), then rolls back.
\set ON_ERROR_STOP on

BEGIN;

INSERT INTO forecast_model (mlflow_run_id, model_version, trained_at, data_period, n_series, n_rows,
  metrics, calibration, feature_importance, model_card, is_current)
VALUES ('check', 'check', now(), '{}', 1, 1, '{}', '{}', '{}', '{}', false);
UPDATE forecast_model SET is_current = false WHERE is_current;
UPDATE forecast_model SET is_current = true WHERE mlflow_run_id = 'check';

INSERT INTO forecast_run (model_id, origin_ts, data_through, horizon_hours, status)
SELECT id, '2026-10-01 00:00', '2026-09-30', 168, 'loading' FROM forecast_model
WHERE mlflow_run_id = 'check';
INSERT INTO forecast_hourly (run_id, source, scope, hour_ts, risk_probability,
  expected_curtailment_pct, applicable)
SELECT id, 'wind', 'NE', '2026-10-01 00:00', 0.5, 10, true FROM forecast_run;
UPDATE forecast_run SET status = 'ready';
DELETE FROM forecast_run;           -- cascades to forecast_hourly
DELETE FROM forecast_model WHERE mlflow_run_id = 'check';

-- The job reads the warehouse tables ...
SELECT count(*) FROM state_monthly_curtailment;

-- ... but must not change them, change other columns, or reach the member data.
DO $$
DECLARE
  stmt text;
BEGIN
  FOREACH stmt IN ARRAY ARRAY[
    'INSERT INTO load_run (dataset, started_at, status) VALUES (''x'', now(), ''running'')',
    'DELETE FROM plant',
    'UPDATE forecast_model SET model_version = ''x''',
    'UPDATE forecast_run SET origin_ts = now()',
    'SELECT count(*) FROM member',
    'SELECT count(*) FROM usage_event',
    'SELECT count(*) FROM member_session'
  ]
  LOOP
    BEGIN
      EXECUTE stmt;
      RAISE EXCEPTION 'energia_forecast must not be able to run: %', stmt;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;
  END LOOP;
END
$$;

ROLLBACK;
\echo energia_forecast: write checks passed
