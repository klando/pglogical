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

DROP FUNCTION pglogical.replication_set_add_table(name, regclass, boolean,
     text[], text);
CREATE FUNCTION pglogical.replication_set_add_table(set_name name, relation regclass, synchronize_data boolean DEFAULT false,
	columns text[] DEFAULT NULL, row_filter text DEFAULT NULL, nsptarget name DEFAULT NULL, reltarget name DEFAULT NULL)
RETURNS boolean CALLED ON NULL INPUT VOLATILE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_replication_set_add_table';

DROP FUNCTION pglogical.replication_set_add_sequence(name, regclass, boolean);
CREATE FUNCTION pglogical.replication_set_add_sequence(set_name name, relation regclass, synchronize_data boolean DEFAULT false, nsptarget name DEFAULT NULL, reltarget name DEFAULT NULL)
RETURNS boolean VOLATILE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_replication_set_add_sequence';

DROP FUNCTION pglogical.show_repset_table_info(regclass, text[]);
CREATE FUNCTION pglogical.show_repset_table_info(relation regclass, repsets text[], OUT relid oid, OUT nspname text,
	OUT relname text, OUT att_list text[], OUT has_row_filter boolean, OUT nsptarget text, OUT reltarget text)
RETURNS record STRICT STABLE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_show_repset_table_info';

CREATE FUNCTION pglogical.show_repset_table_info_by_target(nsptarget name, reltarget name, repsets text[], OUT relid oid, OUT nspname text,
	OUT relname text, OUT att_list text[], OUT has_row_filter boolean, OUT nsptarget text, OUT reltarget text)
RETURNS record STRICT STABLE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_show_repset_table_info_by_target';

CREATE TYPE pglogical.sync_struct_enum
       AS ENUM ('none', 'all');

DROP FUNCTION pglogical.create_subscription(subscription_name name, provider_dsn text,
    replication_sets text[] = '{default,default_insert_only,ddl_sql}', synchronize_structure boolean = false,
    synchronize_data boolean = true, forward_origins text[] = '{all}', apply_delay interval DEFAULT '0');
CREATE FUNCTION pglogical.create_subscription(subscription_name name, provider_dsn text,
    replication_sets text[] = '{default,default_insert_only,ddl_sql}', synchronize_structure pglogical.sync_struct_enum = 'none',
    synchronize_data boolean = true, forward_origins text[] = '{all}', apply_delay interval DEFAULT '0')
RETURNS oid STRICT VOLATILE LANGUAGE c AS 'MODULE_PATHNAME', 'pglogical_create_subscription';
CREATE FUNCTION pglogical.create_subscription(subscription_name name, provider_dsn text,
    replication_sets text[] = '{default,default_insert_only,ddl_sql}', synchronize_structure boolean = false,
    synchronize_data boolean = true, forward_origins text[] = '{all}', apply_delay interval DEFAULT '0')
RETURNS oid STRICT VOLATILE LANGUAGE SQL AS 'select oid from pglogical.create_subscription($1,$2,$3, case when $4 is true then ''all'' else ''none'' end ,$5,$6,$7)';
