ALTER TABLE pglogical.replication_set_table
      ADD COLUMN set_nsptarget name NOT NULL
    , ADD COLUMN set_reltarget name NOT NULL;
ALTER TABLE pglogical.replication_set_seq
      ADD COLUMN set_nsptarget name NOT NULL
    , ADD COLUMN set_seqtarget name NOT NULL;

UPDATE pglogical.replication_set_table
  SET set_nsptarget = n.nspname
    , set_reltarget = c.relname
FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.oid = set_reloid;

UPDATE pglogical.replication_set_seq
  SET set_nsptarget = n.nspname
    , set_seqtarget = c.relname
FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.oid = set_seqoid;

-- a VACUUM FULL of the table above would be nice here.

DROP FUNCTION pglogical.show_repset_table_info(regclass, text[]);
CREATE FUNCTION pglogical.show_repset_table_info(relation regclass, repsets text[], OUT relid oid, OUT nspname text,
	OUT relname text, OUT att_list text[], OUT has_row_filter boolean, OUT nsptarget text, OUT reltarget text)
RETURNS record STRICT STABLE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_show_repset_table_info';

CREATE FUNCTION pglogical.show_repset_table_info_by_target(nsptarget name, reltarget name, repsets text[], OUT relid oid, OUT nspname text,
	OUT relname text, OUT att_list text[], OUT has_row_filter boolean, OUT nsptarget text, OUT reltarget text)
RETURNS record STRICT STABLE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_show_repset_table_info_by_target';
