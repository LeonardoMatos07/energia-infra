\set ON_ERROR_STOP on

BEGIN;

SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'energia_api') AS create_api \gset
\if :create_api
CREATE ROLE energia_api LOGIN;
\endif
ALTER ROLE energia_api WITH LOGIN PASSWORD :'api_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'energia_data') AS create_data \gset
\if :create_data
CREATE ROLE energia_data LOGIN;
\endif
ALTER ROLE energia_data WITH LOGIN PASSWORD :'data_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- energia_forecast: the ML batch job (spillway-forecast, `spillway publish`). Optional until its
-- password exists (-v forecast_password=...), so the script keeps working without it.
SELECT :{?forecast_password} AS with_forecast \gset
\if :with_forecast
SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'energia_forecast') AS create_forecast \gset
\if :create_forecast
CREATE ROLE energia_forecast LOGIN;
\endif
ALTER ROLE energia_forecast WITH LOGIN PASSWORD :'forecast_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
\endif

SELECT current_database() AS dbname \gset
REVOKE ALL ON DATABASE :"dbname" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"dbname" TO energia_api, energia_data;
-- The pipeline stages every load in CREATE TEMP TABLE; REVOKE ALL ... FROM PUBLIC removed the
-- default TEMPORARY privilege, so it has to be granted back to energia_data.
GRANT TEMPORARY ON DATABASE :"dbname" TO energia_data;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO energia_api, energia_data;

-- energia_api: reads everything; writes only the tables the API owns (see README, "5. Database
-- users"). Reset the write privileges first so a table dropped from the list loses them when the
-- script is reapplied.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON ALL TABLES IN SCHEMA public FROM energia_api;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO energia_api;
GRANT INSERT, UPDATE, DELETE ON
  public.monthly_report,
  public.newsletter_subscriber,
  public.organization,
  public.app_user,
  public.member,
  public.member_token,
  public.member_session,
  public.email_dispatch,
  public.usage_event
TO energia_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO energia_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO energia_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO energia_api;

-- energia_data: only the tables the pipeline loads, nothing else (it must not read member data).
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM energia_data;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM energia_data;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.plant,
  public.plant_monthly_curtailment,
  public.state_monthly_curtailment,
  public.subsystem_monthly_curtailment,
  public.hourly_curtailment,
  public.load_run,
  public.subsystem_hourly_balance,
  public.subsystem_monthly_generation,
  public.power_plant,
  public.plant_monthly_generation
TO energia_data;
SELECT pg_get_serial_sequence('public.load_run', 'id') AS load_run_seq \gset
GRANT USAGE, SELECT ON SEQUENCE :load_run_seq TO energia_data;

-- energia_forecast: reads the warehouse tables (to reconcile) but not the member data, and writes
-- only the three forecast tables. The publisher inserts a run, copies the hourly rows, flips the
-- run to `ready` and moves the `is_current` flag of the model in one transaction, so it needs
-- UPDATE on exactly those two columns and nothing else. DELETE purges old runs (forecast_hourly
-- goes with them through ON DELETE CASCADE).
\if :with_forecast
GRANT CONNECT ON DATABASE :"dbname" TO energia_forecast;
GRANT USAGE ON SCHEMA public TO energia_forecast;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM energia_forecast;
GRANT SELECT ON
  public.plant,
  public.plant_monthly_curtailment,
  public.state_monthly_curtailment,
  public.subsystem_monthly_curtailment,
  public.hourly_curtailment,
  public.load_run,
  public.forecast_model,
  public.forecast_run,
  public.forecast_hourly
TO energia_forecast;
GRANT INSERT, DELETE ON public.forecast_model, public.forecast_run, public.forecast_hourly
TO energia_forecast;
GRANT UPDATE (is_current) ON public.forecast_model TO energia_forecast;
GRANT UPDATE (status) ON public.forecast_run TO energia_forecast;
\endif

COMMIT;
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE grantee IN ('energia_api', 'energia_data') AND table_schema = 'public'
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
