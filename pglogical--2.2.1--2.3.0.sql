ALTER TABLE pglogical.replication_set_table
      ADD COLUMN set_nsptarget name
    , ADD COLUMN set_reltarget name;
ALTER TABLE pglogical.replication_set_seq
      ADD COLUMN set_nsptarget name
    , ADD COLUMN set_seqtarget name;
DROP FUNCTION pglogical.show_repset_table_info(regclass, text[]);
CREATE FUNCTION pglogical.show_repset_table_info(relation regclass, repsets text[], OUT relid oid, OUT nspname text,
	OUT relname text, OUT att_list text[], OUT has_row_filter boolean, OUT nsptarget text, OUT reltarget text)
RETURNS record STRICT STABLE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_show_repset_table_info';
