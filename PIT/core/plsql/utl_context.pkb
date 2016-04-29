create or replace package body utl_context
as
  /* PACKAGE CONSTANTS */
  -- Global Constants
  c_package_name constant varchar2(20) := $$PLSQL_UNIT;
  c_true constant char(1) := 'Y';
  c_false constant char(1) := 'N';

  /* Context Type Constants: Context values are visible ...
   * global: ... for any user and any session
   * force_user: ... only if user matches
   * force_client_id: ... only if client_identifier matches
   * force_user_client_id: ... only if user AND client_identifier matches
   * prefer_client_id: ... if a matching value for that client_identifier exists,
   *                       it is visible, otherwise a default value is provided
   * prefer_user_client_id: ... if a matching value for that user AND client_identifier exists,
   *                            it is visible, otherwise a default value is provided
   * session: ... only within the session that set the value (pseduo local context)
   */
  c_global constant varchar2(20) := 'GLOBAL';
  c_force_user constant varchar2(20) := 'FORCE_USER';
  c_force_client_id constant varchar2(20) := 'FORCE_CLIENT_ID';
  c_force_user_client_id constant varchar2(20) := 'FORCE_USER_CLIENT_ID';
  c_prefer_client_id constant varchar2(20) := 'PREFER_CLIENT_ID';
  c_prefer_user_client_id constant varchar2(25) := 'PREFER_USER_CLIENT_ID';
  c_session constant varchar2(20) := 'SESSION';

  -- Parameter Maintenance
  c_parameter_group_id constant varchar2(10) := 'CONTEXT';
  c_parameter_postfix constant varchar2(5) := '_TYPE';
  c_parameter_type constant varchar2(10) := 'STRING';
  c_validation_string constant varchar2(200) :=
    q'[string_value in (
       'GLOBAL', 'FORCE_USER','FORCE_CLIENT_ID',
       'FORCE_USER_CLIENT_ID', 'PREFER_CLIENT_ID',
       'PREFER_USER_CLIENT_ID', 'SESSION')]';

  -- USERENV constants
  c_env constant varchar2(20) := 'USERENV';
  c_client_id constant varchar2(20) := 'CLIENT_IDENTIFIER';
  c_session_id constant varchar2(10) := 'SESSIONID';

  $IF $$PIT_INSTALLED $THEN
  $ELSE
  -- Exception Handling
  c_context constant varchar2(20) := '#CONTEXT#';
  c_no_context_msg constant varchar2(200) :=
   'Context cannot be null.
    Please provide a valid context name.';
  c_invalid_context_msg constant varchar2(200) :=
       ': Context '
    || c_context
    || ' does not exist. Please provide a valid context name that is controlled by '
    || c_package_name
    || '.';
  $END
  
  /* PACKAGE VARS */
  type context_setting_rec is record(
    is_global boolean,
    with_user_name boolean,
    with_client_id boolean,
    with_session_id boolean,
    with_fallback boolean
  );

  type context_settings_tab is table of context_setting_rec
    index by varchar2(30);

  g_context_settings context_settings_tab;
  g_context_setting context_setting_rec;
  g_user varchar2(30);

  /* Helper to check whether a context is maintained by this package
   * @param p_context Name of the context to check
   * @usage Is called internally to assert that a context is maintained by this package
   */
  procedure check_param(
    p_context in varchar2)
  as
  begin
    if p_context is null then
      $IF $$PIT_INSTALLED $THEN
      pit.error(msg.CTX_NO_CONTEXT);
      $ELSE
      raise_application_error(-20999, c_no_context_msg);
      $END
    elsif not g_context_settings.exists(p_context) then
      $IF $$PIT_INSTALLED $THEN
      pit.error(msg.CTX_INVALID_CONTEXT, msg_args(p_context, $$PLSQL_UNIT));
      $ELSE
      raise_application_error(-20998,
        replace(
          c_invalid_context_msg, c_context, p_context));
      $END
    end if;
  end check_param;
  
  
  /* Helper to read metadata for a maintained context
   * @param p_context Name of the context to read
   * @usage Is called internally to read metadata according to type context_setting_rec
   *        for a given context
   */
  procedure read_settings(
    p_context in varchar2)
  as
  begin
    check_param(p_context);
    g_context_setting := g_context_settings(p_context);
  end read_settings;


  /* Helper function to wrap a call to user according to the settings of the context
   * @usage If a context requires a username, it is provided, otherwise null is returned.
   */
  function get_user_name
    return varchar2
  as
  begin
    if g_context_setting.with_user_name then
      return g_user;
    else
      return null;
    end if;
  end get_user_name;


  /* Helper function to wrap a call to sys_contexrt('USERENV', 'CLIENT_IDENTIFIER')
   * @usage if the settings for a given context require a client id, this
   *        function returns its value, otherwise null. 
   *        If the context requires a client_id, this function returns
   *        - the client id
   *        - the client_identifier
   *        - constant c_no_value
   *        whatever is not null, in this order
   *        If the context requires a session_id, it will be returned
   */
  function get_client_id(
    p_client_id varchar2 default null)
    return varchar2
  as
  begin
    case
    when g_context_setting.with_client_id then
      return replace(coalesce(p_client_id, sys_context(c_env, c_client_id)), c_no_value);
    when g_context_setting.with_session_id then
      return sys_context(c_env, c_session_id);
    else
      return null;
    end case;
  end get_client_id;
  
  
  /* Initialization procedure */
  procedure initialize
  as
    cursor ctx_cur is
      select namespace,
             case when type in ('ACCESSED GLOBALLY')
                  then c_true else c_false
                  end is_global
        from dba_context
       where package = c_package_name;
    l_dummy varchar2(30);
    l_context_type varchar2(30);
    l_parameter_id varchar2(30);
    l_empty_ctx_setting context_setting_rec;
  begin
    g_user := user;
    for ctx in ctx_cur loop
      g_context_setting := l_empty_ctx_setting;
      g_context_setting.is_global := case ctx.is_global
        when c_true then true else false end;
      if g_context_setting.is_global then
        l_parameter_id :=
          ctx.namespace || c_parameter_postfix;
        begin
          l_context_type := to_char(param.get_string(
            l_parameter_id, c_parameter_group_id));
        exception
          when no_data_found then
            -- Parameter for context missing
            insert into parameter_tab(
              parameter_id, parameter_group_id, string_value,
              parameter_type_id, validation_string)
            values (
              l_parameter_id, c_parameter_group_id,
              to_clob(c_global), c_parameter_type,
              c_validation_string);
            l_context_type := c_global;
        end;
        case l_context_type
        when c_global then
          null;
        when c_force_user then
          g_context_setting.with_user_name := true;
        when c_force_client_id then
          g_context_setting.with_client_id := true;
        when c_force_user_client_id then
          g_context_setting.with_user_name := true;
          g_context_setting.with_client_id := true;
        when c_prefer_client_id then
          g_context_setting.with_client_id := true;
          g_context_setting.with_fallback := true;
        when c_prefer_user_client_id then
          g_context_setting.with_user_name := true;
          g_context_setting.with_client_id := true;
          g_context_setting.with_fallback := true;
        when c_session then
          g_context_setting.with_user_name := true;
          g_context_setting.with_session_id := true;
        else
          null;
        end case;
      end if;
      g_context_settings(ctx.namespace) :=
        g_context_setting;
    end loop;
  end initialize;
  
  
  procedure set_value(
    p_context in varchar2,
    p_attribute in varchar2,
    p_value in varchar2,
    p_client_id varchar2 default null)
  as
  begin
    read_settings(p_context);

    dbms_session.set_context(
      p_context,
      p_attribute,
      p_value,
      get_user_name,
      get_client_id(p_client_id));
  end set_value;


  function get_with_client_id(
    p_context in varchar2,
    p_attribute in varchar2,
    p_client_id in varchar2)
    return varchar2
  as
    l_value varchar2(4000);
    l_client_identifier varchar2(64);
  begin
    l_client_identifier := sys_context(c_env, c_client_id);
    dbms_session.set_identifier(p_client_id);
    l_value := sys_context(p_context, p_attribute);
    dbms_session.set_identifier(l_client_identifier);
    return l_value;
  end get_with_client_id;


  function get_value(
    p_context in varchar2,
    p_attribute in varchar2,
    p_client_id varchar2 default null)
    return varchar2
  as
    l_value varchar2(4000);
  begin
    read_settings(p_context);
    l_value := sys_context(p_context, p_attribute);
    case
    when l_value is null and g_context_setting.with_fallback
    then -- Fallback auf allgemeinen Parameter
      l_value := get_with_client_id(
                   p_context, p_attribute, '');
    when l_value is null and
         g_context_setting.with_session_id
    then -- Lese sessionspezifischen Parameter
      l_value := get_with_client_id(
                   p_context, p_attribute,
                   nvl(p_client_id, sys_context(c_env, c_session_id)));
    else
      null;
    end case;
    return l_value;
  end get_value;


  procedure clear_value(
    p_context in varchar2,
    p_attribute in varchar2,
    p_client_id varchar2 default null)
  as
  begin
    read_settings(p_context);
    dbms_session.clear_context(
      p_context, nvl(p_client_id, get_client_id), p_attribute);
  end clear_value;


  procedure reset_context(
    p_context in varchar2)
  as
  begin
    dbms_session.clear_all_context(p_context);
    initialize;
  end reset_context;


begin
  initialize;
end utl_context;
/