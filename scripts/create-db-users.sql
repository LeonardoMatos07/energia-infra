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

SELECT current_database() AS dbname \gset
REVOKE ALL ON DATABASE :"dbname" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"dbname" TO energia_api, energia_data;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO energia_api, energia_data;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO energia_api;
GRANT INSERT, UPDATE, DELETE ON
  public.monthly_report,
  public.newsletter_subscriber,
  public.organization,
  public.app_user
TO energia_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO energia_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO energia_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO energia_api;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM energia_data;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.plant,
  public.plant_monthly_curtailment,
  public.state_monthly_curtailment,
  public.subsystem_monthly_curtailment,
  public.load_run
TO energia_data;
SELECT pg_get_serial_sequence('public.load_run', 'id') AS load_run_seq \gset
GRANT USAGE, SELECT ON SEQUENCE :load_run_seq TO energia_data;

COMMIT;
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE grantee IN ('energia_api', 'energia_data') AND table_schema = 'public'
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
