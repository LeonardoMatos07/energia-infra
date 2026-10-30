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

-- Tariff-flag forecast: insert a run, its children, flip to ready, score it, purge (cascade).
INSERT INTO flag_forecast_run (target_month, lead_days, generated_at, data_through, model_version,
  rule_version, status)
VALUES ('2026-11-01', 7, now(), '2026-10-24', 'check', 'check', 'loading');
INSERT INTO flag_forecast_prob (run_id, flag, prob, band_lower_brl_per_mwh, band_upper_brl_per_mwh)
SELECT id, 'Verde', 0.6, 57.31, 98.14 FROM flag_forecast_run;
INSERT INTO flag_forecast_input (run_id, inputs) SELECT id, '{}' FROM flag_forecast_run;
UPDATE flag_forecast_run SET status = 'ready';
INSERT INTO flag_forecast_score (run_id, actual_flag, prob_actual, brier, top_hit)
SELECT id, 'Verde', 0.6, 0.16, true FROM flag_forecast_run;
SELECT count(*) FROM flag_rule_month;
SELECT count(*) FROM tariff_flag_monthly;
SELECT count(*) FROM pld_weekly;
SELECT count(*) FROM subsystem_storage_daily;
DELETE FROM flag_forecast_run;      -- cascades to prob, input and score

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
    'UPDATE flag_forecast_run SET lead_days = 1',
    'UPDATE flag_forecast_score SET brier = 0',
    'INSERT INTO flag_rule_month (month) VALUES (''2026-01-01'')',
    'DELETE FROM tariff_flag_monthly',
    'DELETE FROM pld_weekly',
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
