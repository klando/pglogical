SELECT * FROM pglogical_regress_variables()
\gset

\c :provider_dsn
CREATE SCHEMA "map.ping";
CREATE TABLE "map.ping".test_origin(id serial primary key, data text DEFAULT '');
INSERT INTO "map.ping".test_origin(data) VALUES ('a');
INSERT INTO "map.ping".test_origin(data) VALUES ('b');
CREATE TABLE "map.ping".test_origin2(id int primary key, data text DEFAULT '');
INSERT INTO "map.ping".test_origin2(id,data) VALUES (998,'y');
INSERT INTO "map.ping".test_origin2(id,data) VALUES (999,'z');
CREATE TABLE "map.ping".bad(id serial primary key, data text DEFAULT '');

\c :subscriber_dsn
CREATE SCHEMA "ping.map";
CREATE SCHEMA "ping2.map2";
CREATE TABLE "ping.map".test_target(id serial primary key, data text DEFAULT '');
CREATE TABLE "ping2.map2".test_target2(id serial primary key, data text DEFAULT '');

-- test replication with initial copy
-- add table and sequence to the subscribed replication set
\c :provider_dsn
SELECT * FROM pglogical.create_replication_set('map1',
       replicate_insert:=true,
       replicate_update:=true,
       replicate_delete:=true,
       replicate_truncate:=true);
SELECT * FROM pglogical.replication_set_add_table('map1', '"map.ping".test_origin', true, nsptarget:='ping.map', reltarget:='test_target');
SELECT * FROM pglogical.replication_set_add_sequence('map1', pg_get_serial_sequence('"map.ping".test_origin', 'id'), nsptarget:='ping.map',  reltarget:='test_target_id_seq'); -- XXX not  a dynamic name ...
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT * FROM pglogical.create_subscription(
    subscription_name := 'test_map1',
    provider_dsn := (SELECT provider_dsn FROM pglogical_regress_variables()) || ' user=super',
	synchronize_structure := false,
	forward_origins := '{}',
        replication_sets := '{map1}');
SELECT pglogical.wait_for_subscription_sync_complete('test_map1');
SELECT * FROM "ping.map".test_target;

-- test DML replication after init
\c :provider_dsn
INSERT INTO "map.ping".test_origin(data) VALUES ('c');
INSERT INTO "map.ping".test_origin(data) VALUES ('d');
UPDATE "map.ping".test_origin SET data = 'data';
DELETE FROM "map.ping".test_origin WHERE id < 3;
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT * FROM "ping.map".test_target;

-- test distinct targets and sequences for a table in distinct sets (a.b -> c.d and a.b -> e.f)
-- TODO add sync sequence test to this case
\c :provider_dsn
SELECT * FROM pglogical.create_replication_set('map2',
       replicate_insert:=true,
       replicate_update:=true,
       replicate_delete:=true,
       replicate_truncate:=true);
SELECT * FROM pglogical.replication_set_add_table('map2', '"map.ping".test_origin', true, nsptarget:='ping2.map2', reltarget:='test_target2');
SELECT * FROM pglogical.replication_set_add_sequence('map2', pg_get_serial_sequence('"map.ping".test_origin', 'id'), nsptarget:='ping2.map2',  reltarget:='test_target2_id_seq'); -- XXX not  a dynamic name ...
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT * FROM pglogical.create_subscription(
    subscription_name := 'test_map2',
    provider_dsn := (SELECT provider_dsn FROM pglogical_regress_variables()) || ' user=super',
	synchronize_structure := false,
	forward_origins := '{}',
        replication_sets := '{map2}');
SELECT pglogical.wait_for_subscription_sync_complete('test_map2');
SELECT * FROM "ping2.map2".test_target2;

-- test merge data from 2 tables into 1
\c :provider_dsn
SELECT * FROM pglogical.replication_set_add_table('map1', '"map.ping".test_origin2', true, nsptarget:='ping2.map2', reltarget:='test_target2');
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT * FROM "ping2.map2".test_target2;

-- test merging 2 sequences to the same target: not allowed !
\c :provider_dsn
SELECT * FROM pglogical.replication_set_add_sequence('map1', pg_get_serial_sequence('"map.ping".bad', 'id'), nsptarget:='ping.map',  reltarget:='test_target_id_seq'); -- XXX not  a dynamic name ...
DROP TABLE "map.ping".bad;

-- XXX copy test required ?

-- test synchronize
\c :subscriber_dsn
DELETE FROM "ping.map".test_target WHERE id > 1;
SELECT * FROM pglogical.alter_subscription_synchronize('test_map1');
SELECT pglogical.wait_for_table_sync_complete('test_map1', '"ping.map".test_target');
SELECT * FROM "ping.map".test_target;
DELETE FROM "ping.map".test_target WHERE id > 1;
SELECT * FROM pglogical.alter_subscription_resynchronize_table('test_map1', '"ping.map".test_target');
SELECT pglogical.wait_for_table_sync_complete('test_map1', '"ping.map".test_target');
SELECT * FROM "ping.map".test_target;


-- truncate
\c :provider_dsn
TRUNCATE "map.ping".test_origin;
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT * FROM "ping.map".test_target;

\c :provider_dsn
SELECT pglogical.synchronize_sequence(c.oid)
  FROM pg_class c, pg_namespace n
  WHERE c.relkind = 'S' AND c.relnamespace = n.oid AND n.nspname IN ('map.ping');
SELECT pglogical.wait_slot_confirm_lsn(NULL, NULL);
\c :subscriber_dsn
SELECT N.nspname AS schemaname, C.relname AS tablename, (nextval(C.oid) > 1000) as synced
  FROM pg_class C JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE C.relkind = 'S' AND N.nspname IN ('public', 'ping.map')
  ORDER BY 1, 2;

-- XXX check synchronize structure ... ?

-- test wait for subscription sync complete
\c :subscriber_dsn
SELECT pglogical.wait_for_subscription_sync_complete('test_map1');

-- show and cleaning
\c :subscriber_dsn
SELECT * FROM pglogical.show_subscription_status('test_map1');
SELECT * FROM pglogical.show_subscription_table('test_map1','"ping.map".test_target');
SELECT * FROM pglogical.drop_subscription('test_map1');
SELECT * FROM pglogical.drop_subscription('test_map2');

\c :provider_dsn
SELECT nspname, relname, att_list, has_row_filter, nsptarget, reltarget
FROM pglogical.show_repset_table_info_by_target('ping.map','test_target', ARRAY['map1']);
-- XXX fonction pglogical.table_data_filtered(anyelement,regclass,text[]) ?
SELECT * FROM pglogical.replication_set_seq;
SELECT * FROM pglogical.replication_set_table;
SELECT cache_size,last_value FROM pglogical.sequence_state;
SELECT * FROM pglogical.drop_replication_set('map1');
SELECT * FROM pglogical.drop_replication_set('map2');
DROP SCHEMA "map.ping" CASCADE;

\c :subscriber_dsn
DROP SCHEMA "ping.map" CASCADE;
DROP SCHEMA "ping2.map2" CASCADE;
