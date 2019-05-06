SELECT * FROM pglogical_regress_variables()
\gset

\c :provider_dsn
-- test adding a sequence with add_all_sequences (special case to get schema and
-- relation names)
CREATE SEQUENCE test_sequence;

SELECT * FROM pglogical.create_replication_set('relations',
       replicate_insert:=true,
       replicate_update:=true,
       replicate_delete:=true,
       replicate_truncate:=true);
SELECT * FROM pglogical.replication_set_add_all_sequences('relations', '{public}');
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);

\c :subscriber_dsn
SELECT * FROM pglogical.create_subscription(
    subscription_name := 'test_relations',
    provider_dsn := (SELECT provider_dsn FROM pglogical_regress_variables()) || ' user=super',
	synchronize_structure := 'relations_only',
	forward_origins := '{}',
        replication_sets := '{relations}');

set statement_timeout='10s';
SELECT pglogical.wait_for_subscription_sync_complete('test_relations');
reset statement_timeout;

SELECT * FROM pglogical.drop_subscription('test_relations');

\c :provider_dsn
SELECT * FROM pglogical.replication_set_seq;
SELECT * FROM pglogical.drop_replication_set('relations');
DROP SEQUENCE test_sequence CASCADE;

\c :subscriber_dsn
DROP SEQUENCE test_sequence CASCADE;
