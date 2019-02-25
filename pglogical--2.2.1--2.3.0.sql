ALTER TABLE pglogical.replication_set_table
      ADD COLUMN set_nsptarget name
    , ADD COLUMN set_reltarget name;
ALTER TABLE pglogical.replication_set_seq
      ADD COLUMN set_nsptarget name
    , ADD COLUMN set_seqtarget name;
