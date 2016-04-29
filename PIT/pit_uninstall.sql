set verify off
set serveroutput on
set echo off
set feedback off
set lines 120
set pages 9999
whenever sqlerror exit
clear screen

define INSTALL_USER = &1.;
define REMOTE_USER = &2.;
define INSTALL_ON_DEV = true

define section="********************************************************************************"
define h1="*** "
define h2="**  "
define h3="*   "
define s1=".    - "

alter session set current_schema=&INSTALL_USER.;

prompt &section.

prompt &h1.Deinstall OUTPUT-MODULES
prompt &h2.Module PIT_CONSOLE
@modules/pit_console/sql/clean_up.sql
prompt &h2.Module PIT_TABLE
@modules/pit_table/sql/clean_up.sql
prompt &h2.Module PIT_APEX
@modules/pit_apex/sql/clean_up.sql
prompt &h2.Module PIT_FILE
@modules/pit_file/sql/clean_up.sql
prompt &h2.Module PIT_MAIL
@modules/pit_mail/sql/clean_up.sql
prompt &h2.Module PIT_TEST
@modules/pit_test/sql/clean_up.sql

prompt &h1.PL/SQL INSTRUMENTATION TOOLKIT (PIT) Deinstallation
prompt &h1.Deinstall CORE Functionality
@core/clean_up_install.sql
alter session set current_schema=&REMOTE_USER.;
@core/clean_up_remote.sql
alter session set current_schema=&INSTALL_USER.;
@core/clean_up_remote.sql

prompt &h1.Deinstall CONTEXT Framework
@core/context/clean_up.sql

prompt &h1.Deinstall PARAMETER Framework
@core/parameters/clean_up_install.sql
alter session set current_schema=&REMOTE_USER.;
@core/parameters/clean_up_remote.sql
alter session set current_schema=&INSTALL_USER.;

exit;