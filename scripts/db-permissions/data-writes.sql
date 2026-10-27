-- Run as energia_data. Mirrors what the pipeline does (stage a load in a temporary table, upsert
-- it, replace a range, record the run) on every table it owns, then rolls back.
\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE stage_plant (LIKE plant INCLUDING DEFAULTS) ON COMMIT DROP;
INSERT INTO stage_plant (id, kind, name, slug, source, state, subsystem)
VALUES ('P1', 'plant', 'Plant 1', 'plant-1', 'wind', 'RN', 'NE');
INSERT INTO plant (id, kind, name, slug, source, state, subsystem)
SELECT id, kind, name, slug, source, state, subsystem FROM stage_plant
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, updated_at = now();
UPDATE plant SET name = 'Plant 1b' WHERE id = 'P1';

INSERT INTO plant_monthly_curtailment (plant_id, month, verified_generation_mwh, curtailed_mwh,
  curtailed_rel_mwh, curtailed_cnf_mwh, curtailed_ene_mwh, curtailed_other_mwh, restricted_hours)
VALUES ('P1', '2026-09-01', 1, 1, 0, 0, 1, 0, 1);
DELETE FROM plant_monthly_curtailment WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO state_monthly_curtailment (state, source, month, verified_generation_mwh, curtailed_mwh,
  curtailed_rel_mwh, curtailed_cnf_mwh, curtailed_ene_mwh, curtailed_other_mwh, affected_plants)
VALUES ('RN', 'total', '2026-09-01', 1, 1, 0, 0, 1, 0, 1);
DELETE FROM state_monthly_curtailment WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO subsystem_monthly_curtailment (subsystem, source, month, verified_generation_mwh,
  curtailed_mwh, curtailed_rel_mwh, curtailed_cnf_mwh, curtailed_ene_mwh, curtailed_other_mwh,
  affected_plants)
VALUES ('SIN', 'total', '2026-09-01', 1, 1, 0, 0, 1, 0, 1);
DELETE FROM subsystem_monthly_curtailment WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO hourly_curtailment (subsystem, source, month, day_type, hour, curtailed_mwh,
  generation_mwh, days)
VALUES ('SIN', 'total', '2026-09-01', 'weekday', 12, 1, 1, 1);
DELETE FROM hourly_curtailment WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO load_run (dataset, started_at, status) VALUES ('check', now(), 'running');
UPDATE load_run SET status = 'success', finished_at = now() WHERE dataset = 'check';
DELETE FROM load_run WHERE dataset = 'check';

DELETE FROM plant WHERE id = 'P1';

-- The pipeline must not reach the API's tables, least of all the member data.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['member', 'member_token', 'member_session', 'usage_event',
                           'monthly_report', 'newsletter_subscriber', 'organization', 'app_user']
  LOOP
    BEGIN
      EXECUTE format('SELECT count(*) FROM %I', t);
      RAISE EXCEPTION 'energia_data must not be able to read %', t;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;
  END LOOP;
END
$$;

ROLLBACK;
\echo energia_data: write checks passed
