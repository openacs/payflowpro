declare
  foo integer;
begin
  foo := acs_sc_impl.delete_alias(
    'PaymentGateway',
    'payflowpro',
    'Authorize'
  );

  foo := acs_sc_impl.delete_alias(
    'PaymentGateway',
    'payflowpro',
    'ChargeCard'
  );

  foo := acs_sc_impl.delete_alias(
    'PaymentGateway',
    'payflowpro',
    'Return'
  );

  foo := acs_sc_impl.delete_alias(
    'PaymentGateway',
    'payflowpro',
    'Void'
  );

  foo := acs_sc_impl.delete_alias(
    'PaymentGateway',
    'payflowpro',
    'info'
  );

  acs_sc_binding.delete(
    contract_name => 'PaymentGateway',
    impl_name => 'payflowpro'
  );

  acs_sc_impl.delete(
    'PaymentGateway',
    'payflowpro'
  );
end;
/
show errors

drop table payflowpro_result_log;
