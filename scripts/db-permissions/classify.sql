-- Run as the admin user. Every table in the schema has to be classified here, so adding a table in
-- an energia-api migration fails the check until someone decides who may write to it and updates
-- create-db-users.sql, api-writes.sql, data-writes.sql or forecast-writes.sql accordingly.
\set ON_ERROR_STOP on

DO $$
DECLARE
  api_writes   text[] := ARRAY['monthly_report', 'newsletter_subscriber', 'organization', 'app_user',
                               'member', 'member_token', 'member_session', 'email_dispatch',
                               'usage_event'];
  data_writes  text[] := ARRAY['plant', 'plant_monthly_curtailment', 'state_monthly_curtailment',
                               'subsystem_monthly_curtailment', 'hourly_curtailment', 'load_run',
                               'subsystem_hourly_balance', 'subsystem_monthly_generation', 'power_plant', 'plant_monthly_generation'];
  forecast_writes text[] := ARRAY['forecast_model', 'forecast_run', 'forecast_hourly'];
  ignored      text[] := ARRAY['alembic_version'];
  unclassified text;
  missing      text;
BEGIN
  SELECT string_agg(tablename, ', ' ORDER BY tablename) INTO unclassified
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename <> ALL (api_writes || data_writes || forecast_writes || ignored);
  IF unclassified IS NOT NULL THEN
    RAISE EXCEPTION 'tables without a database-user decision: %. Grant them in create-db-users.sql and add them to classify.sql and the matching *-writes.sql.', unclassified;
  END IF;

  SELECT string_agg(t, ', ') INTO missing
  FROM unnest(api_writes || data_writes || forecast_writes) AS t
  WHERE NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t);
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'classified tables that do not exist: %', missing;
  END IF;
END
$$;
