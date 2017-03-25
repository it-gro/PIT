define file_dir=modules/pit_file/
define sql_dir=&file_dir.sql/
define plsql_dir=&file_dir.plsql/

prompt
prompt &section.
prompt &h1.Module PIT_FILE
prompt &h2.Clean up existing installation
@&file_dir.clean_up_install.sql

prompt
prompt &h2.Grant user rights for PIT_FILE
prompt &h3.Grant user rights to &INSTALL_USER.
@&file_dir.user_grants.sql

prompt &h2.Create types adn packages
prompt &s1.Create type PIT_FILE
@&sql_dir.types/pit_file.tps
show errors

prompt &s1.Create package PIT_FILE_PKG
@&plsql_dir.pit_file_pkg.pks
show errors

prompt &s1.Create type body PIT_FILE
@&sql_dir.types/pit_file.tpb
show errors

prompt &s1.Create package body PIT_FILE_PKG
@&plsql_dir.pit_file_pkg.pkb
show errors

prompt &s1.Create PIT_FILE parameters
@&file_dir.create_parameters.sql

prompt ### CAVE ###
prompt Please remember to create a directory called PIT_FILE_DIR before use.
prompt This directory is required to enable PIT to store files.
prompt 