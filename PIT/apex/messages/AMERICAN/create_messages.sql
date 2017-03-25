begin
  pit_admin.merge_message(
    p_pms_name => 'PIT_INVALID_INTEGER',
    p_pms_text => 'Input was expected to be an integer, but was #1#.',
    p_pms_pse_id => 40,
    p_pms_pml_name => 'AMERICAN');
    
    
  pit_admin.merge_message(
    p_pms_name => 'PAR_PGR_EXPORTED',
    p_pms_text => 'Param group #1# exported.',
    p_pms_pse_id => 60,
    p_pms_pml_name => 'AMERICAN');
    
  commit;
  
  pit_admin.create_message_package;
end;
/