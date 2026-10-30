-- Run as energia_api. Writes one valid row to every table the API owns, updates and deletes it,
-- and rolls everything back. A missing INSERT, UPDATE or DELETE grant, or a missing sequence
-- grant for an identity column, fails with "permission denied".
\set ON_ERROR_STOP on

BEGIN;

INSERT INTO organization (id, name) VALUES ('00000000-0000-0000-0000-0000000000a1', 'Acme');
UPDATE organization SET name = 'Acme 2' WHERE id = '00000000-0000-0000-0000-0000000000a1';

INSERT INTO app_user (id, cognito_sub, email, role, organization_id)
VALUES ('00000000-0000-0000-0000-0000000000a2', 'sub-1', 'admin@example.org', 'admin',
        '00000000-0000-0000-0000-0000000000a1');
UPDATE app_user SET name = 'Admin' WHERE id = '00000000-0000-0000-0000-0000000000a2';
DELETE FROM app_user WHERE id = '00000000-0000-0000-0000-0000000000a2';
DELETE FROM organization WHERE id = '00000000-0000-0000-0000-0000000000a1';

INSERT INTO monthly_report (month, title, slug, content)
VALUES ('2026-09-01', 'September', 'report-2026-09', '# Body');
UPDATE monthly_report SET summary = 'Summary' WHERE slug = 'report-2026-09';
DELETE FROM monthly_report WHERE slug = 'report-2026-09';

INSERT INTO newsletter_subscriber (email, consented_at, unsubscribe_token_hash)
VALUES ('reader@example.org', now(), 'hash');
UPDATE newsletter_subscriber SET confirmed_at = now() WHERE email = 'reader@example.org';
DELETE FROM newsletter_subscriber WHERE email = 'reader@example.org';

INSERT INTO member (id, email, password_hash, name, role, regions, plants, interests,
                    marketing_opt_in, privacy_consent_at, lead_score, lead_tier)
VALUES ('00000000-0000-0000-0000-0000000000b1', 'member@example.org', 'scrypt$x', 'Member',
        'professional', '[]', '[]', '[]', false, now(), 0, 'cold');
UPDATE member SET last_login_at = now() WHERE id = '00000000-0000-0000-0000-0000000000b1';

INSERT INTO member_token (member_id, kind, token_hash, expires_at)
VALUES ('00000000-0000-0000-0000-0000000000b1', 'verify', 'token-hash', now());
UPDATE member_token SET attempts = attempts + 1 WHERE token_hash = 'token-hash';
DELETE FROM member_token WHERE token_hash = 'token-hash';

INSERT INTO member_session (member_id, token_hash, expires_at)
VALUES ('00000000-0000-0000-0000-0000000000b1', 'session-hash', now());
DELETE FROM member_session WHERE token_hash = 'session-hash';

INSERT INTO email_dispatch (kind, month, status, recipients, sent, failed)
VALUES ('report', '2000-01-01', 'running', 0, 0, 0);
UPDATE email_dispatch SET status = 'done', sent = 1 WHERE kind = 'report' AND month = '2000-01-01';
DELETE FROM email_dispatch WHERE kind = 'report' AND month = '2000-01-01';

INSERT INTO usage_event (category, action, properties, is_bot, member_id)
VALUES ('page', 'page.view', '{}', false, '00000000-0000-0000-0000-0000000000b1');
UPDATE usage_event SET member_id = NULL WHERE action = 'page.view';
DELETE FROM usage_event WHERE action = 'page.view';

DELETE FROM member WHERE id = '00000000-0000-0000-0000-0000000000b1';

-- Moderation: the API may only touch the admin columns of the news tables (a WHERE false update
-- still checks the column privileges).
UPDATE news_item SET status = 'hidden', editor_note = 'n', editor_note_by = 'me',
  editor_note_at = now(), related_links = '[]' WHERE false;
UPDATE regulatory_act SET status = 'hidden' WHERE false;
DO $$
BEGIN
  BEGIN
    UPDATE news_item SET title = 'x' WHERE false;
    RAISE EXCEPTION 'energia_api must not be able to rewrite the title of a news item';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    DELETE FROM news_item;
    RAISE EXCEPTION 'energia_api must not be able to delete news items';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    INSERT INTO news_source (slug, publisher_name, homepage_url, fetch_method, license_code, license_url)
    VALUES ('x', 'x', 'x', 'rss', 'x', 'x');
    RAISE EXCEPTION 'energia_api must not be able to write news_source';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;

-- The API reads everything, including the pipeline tables...
SELECT count(*) FROM plant;
SELECT count(*) FROM hourly_curtailment;

-- ...but must not write them.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['plant', 'plant_monthly_curtailment', 'state_monthly_curtailment',
                           'subsystem_monthly_curtailment', 'hourly_curtailment', 'load_run',
                           'subsystem_hourly_balance', 'subsystem_monthly_generation', 'power_plant', 'plant_monthly_generation']
  LOOP
    BEGIN
      EXECUTE format('DELETE FROM %I', t);
      RAISE EXCEPTION 'energia_api must not be able to write %', t;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;
  END LOOP;
END
$$;

ROLLBACK;
\echo energia_api: write checks passed
