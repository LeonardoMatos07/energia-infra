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

INSERT INTO power_plant (id, name, slug, source_type) VALUES ('P1', 'Plant 1', 'plant-1', 'hydro');
INSERT INTO power_plant (id, name, slug, source_type)
SELECT 'P1', 'Plant 1', 'plant-1', 'hydro'
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, updated_at = now();
INSERT INTO plant_monthly_generation (month, plant_id, energy_mwh, avg_mw, peak_mw)
VALUES ('2026-09-01', 'P1', 1, 1, 1);
DELETE FROM plant_monthly_generation WHERE month >= '2026-09-01' AND month < '2026-10-01';
DELETE FROM power_plant WHERE id = 'P1';

INSERT INTO subsystem_monthly_generation (month, subsystem, source, energy_mwh, avg_mw, peak_mw)
VALUES ('2026-09-01', 'SIN', 'hydro', 1, 1, 1);
DELETE FROM subsystem_monthly_generation WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO subsystem_hourly_balance (hour, subsystem, hour_utc)
VALUES ('2026-09-01 00:00', 'NE', '2026-09-01 03:00');
DELETE FROM subsystem_hourly_balance WHERE hour >= '2026-09-01' AND hour < '2026-10-01';

INSERT INTO interchange_hourly (hour, origin, destination, scope, hour_utc)
VALUES ('2026-09-01 00:00', 'NE', 'SE', 'national', '2026-09-01 03:00');
DELETE FROM interchange_hourly WHERE hour >= '2026-09-01' AND hour < '2026-10-01';

INSERT INTO interchange_monthly (month, origin, destination, scope, energy_mwh, avg_mw, peak_mw, min_mw)
VALUES ('2026-09-01', 'NE', 'SE', 'national', 1, 1, 1, 1);
DELETE FROM interchange_monthly WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO thermal_dispatch_monthly (month, plant_code, reason, plant_name, subsystem, verified_mwh)
VALUES ('2026-09-01', '201', 'total', 'Plant', 'N', 1);
DELETE FROM thermal_dispatch_monthly WHERE month >= '2026-09-01' AND month < '2026-10-01';

INSERT INTO reservoir (id, name, slug) VALUES ('R1', 'Reservoir 1', 'reservoir-1');
INSERT INTO reservoir (id, name, slug)
SELECT 'R1', 'Reservoir 1', 'reservoir-1'
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, updated_at = now();
INSERT INTO reservoir_daily (day, reservoir_id, storage_pct) VALUES ('2026-09-01', 'R1', 50);
DELETE FROM reservoir_daily WHERE day >= '2026-09-01' AND day < '2026-10-01';
DELETE FROM reservoir WHERE id = 'R1';

INSERT INTO subsystem_storage_daily (day, subsystem, storage_pct) VALUES ('2026-09-01', 'SE', 50);
DELETE FROM subsystem_storage_daily WHERE day >= '2026-09-01' AND day < '2026-10-01';

INSERT INTO plant_monthly_spilled_energy (month, plant_code, plant_name, spilled_energy_mwh,
  spilled_turbinable_energy_mwh)
VALUES ('2026-09-01', '99', 'Plant', 1, 1);
DELETE FROM plant_monthly_spilled_energy WHERE month >= '2026-09-01' AND month < '2026-10-01';

-- versioned snapshots: close the rows that changed, insert the new versions, undo a same-day rerun
INSERT INTO transmission_line (equipment_code, valid_from, row_hash) VALUES ('L1', '2026-10-01', 'h1');
UPDATE transmission_line SET valid_to = '2026-11-01' WHERE valid_to IS NULL AND equipment_code = 'L1';
DELETE FROM transmission_line WHERE valid_from = '2026-10-01';

INSERT INTO substation (station_id, valid_from, row_hash) VALUES ('S1', '2026-10-01', 'h1');
UPDATE substation SET valid_to = '2026-11-01' WHERE valid_to IS NULL AND station_id = 'S1';
DELETE FROM substation WHERE valid_from = '2026-10-01';

INSERT INTO transformer_capacity (equipment_code, valid_from, row_hash) VALUES ('T1', '2026-10-01', 'h1');
UPDATE transformer_capacity SET valid_to = '2026-11-01' WHERE valid_to IS NULL AND equipment_code = 'T1';
DELETE FROM transformer_capacity WHERE valid_from = '2026-10-01';

INSERT INTO news_item (source_id, url, title, summary, published_at, fetched_at, content_hash, topics)
SELECT id, 'https://example.org/n/1', 'Title', 'Summary', now(), now(), 'h1', '["outros"]'
FROM news_source WHERE slug = 'aneel';
INSERT INTO news_item (source_id, url, title, published_at, fetched_at, content_hash, topics)
SELECT id, 'https://example.org/n/1', 'Title 2', now(), now(), 'h2', '[]'
FROM news_source WHERE slug = 'aneel'
ON CONFLICT (url) DO UPDATE SET title = EXCLUDED.title, content_hash = EXCLUDED.content_hash,
  fetched_at = EXCLUDED.fetched_at, topics = EXCLUDED.topics;
INSERT INTO regulatory_act (organ, act_type, title, dou_date, dou_url, topics, content_hash,
                            fetched_at)
VALUES ('ANEEL', 'Resolução', 'Act', '2026-09-01', 'https://example.org/dou/1', '[]', 'h', now())
ON CONFLICT (dou_url, content_hash) DO UPDATE SET title = EXCLUDED.title;

-- The moderation columns and the source catalog are not the pipeline's to write.
DO $$
BEGIN
  BEGIN
    UPDATE news_item SET status = 'hidden';
    RAISE EXCEPTION 'energia_data must not be able to change news_item.status';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    UPDATE news_item SET editor_note = 'x';
    RAISE EXCEPTION 'energia_data must not be able to write news_item.editor_note';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    UPDATE news_source SET active = false;
    RAISE EXCEPTION 'energia_data must not be able to write news_source';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;

-- market prices (CCEE) and quality of supply (ANEEL)
INSERT INTO pld_hourly (hour_utc, hour, subsystem, variant, method, pld_brl_per_mwh)
VALUES ('2026-09-01 03:00', '2026-09-01 00:00', 'SE', 'official', 'official', 100);
DELETE FROM pld_hourly WHERE variant = 'official' AND hour >= '2026-09-01' AND hour < '2026-09-02';

INSERT INTO pld_weekly (week_start, subsystem, pld_avg_brl_per_mwh) VALUES ('2026-09-05', 'SE', 100);
DELETE FROM pld_weekly WHERE week_start = '2026-09-05';

INSERT INTO pld_daily (day, subsystem, pld_avg_brl_per_mwh, pld_min_brl_per_mwh, pld_max_brl_per_mwh,
  hours_at_floor, hours_at_cap, hours) VALUES ('2026-09-01', 'SE', 100, 57.31, 250, 0, 0, 24);
DELETE FROM pld_daily WHERE day >= '2026-09-01';

INSERT INTO pld_monthly (month, subsystem, pld_avg_brl_per_mwh, pld_min_brl_per_mwh,
  pld_max_brl_per_mwh, hours_at_floor, hours_at_cap, hours)
VALUES ('2026-09-01', 'SE', 100, 57.31, 250, 0, 0, 720);
DELETE FROM pld_monthly WHERE month >= '2026-09-01';

INSERT INTO distributor (cnpj, acronym) VALUES ('1', 'TEST');
INSERT INTO consumer_unit_set (distributor_cnpj, set_id, set_name) VALUES ('1', 'a', 'Set A');
INSERT INTO reliability_monthly (month, distributor_cnpj, set_id, consumers, dec_hours, fec_count)
VALUES ('2026-09-01', '1', 'a', 10, 1.5, 0.5);
DELETE FROM reliability_monthly WHERE month >= '2026-09-01';
DELETE FROM consumer_unit_set WHERE distributor_cnpj = '1';
DELETE FROM distributor WHERE cnpj = '1';

-- tariff flags (ANEEL) and the free market (CCEE)
INSERT INTO tariff_flag_monthly (month, flag, additional_brl_per_mwh) VALUES ('2026-09-01', 'Amarela', 18.85);
DELETE FROM tariff_flag_monthly WHERE month = '2026-09-01';

INSERT INTO flag_rule_month (month, rule_version, pld_min_brl_per_mwh, pld_max_brl_per_mwh, gh_mwmed,
  gf_mwmed, gsf, pld_trigger_brl_per_mwh, green_upper_brl_per_mwh, yellow_upper_brl_per_mwh,
  red1_upper_brl_per_mwh, flag)
VALUES ('2026-08-01', 'check', 57.31, 758.27, 37885, 52911, 0.72, 128.67, 98.14, 246.40, 339.47,
  'Amarela');
UPDATE flag_rule_month SET revised_on = '2026-08-02' WHERE month = '2026-08-01';
DELETE FROM flag_rule_month WHERE month = '2026-08-01';

INSERT INTO market_consumption_monthly (month, regulated_mw_avg, free_mw_avg)
VALUES ('2026-09-01', 45000, 15000);
DELETE FROM market_consumption_monthly WHERE month = '2026-09-01';

INSERT INTO market_agents_monthly (month, agent_class, agents) VALUES ('2026-09-01', 'Comercializador', 500);
DELETE FROM market_agents_monthly WHERE month = '2026-09-01';

-- the registry of sources is owned by the migration: the pipeline must not rewrite licenses
DO $$
BEGIN
  BEGIN
    UPDATE data_source SET license_code = 'x';
    RAISE EXCEPTION 'energia_data must not be able to write data_source';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;

-- The pipeline must not reach the API's tables, least of all the member data.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['member', 'member_token', 'member_session', 'email_dispatch', 'usage_event',
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
