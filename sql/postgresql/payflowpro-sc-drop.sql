  select acs_sc_impl_alias__delete(
    'PaymentGateway',
    'payflowpro',
    'Authorize'
  );

  select acs_sc_impl_alias__delete(
    'PaymentGateway',
    'payflowpro',
    'ChargeCard'
  );

  select acs_sc_impl_alias__delete(
    'PaymentGateway',
    'payflowpro',
    'Return'
  );

  select acs_sc_impl_alias__delete(
    'PaymentGateway',
    'payflowpro',
    'Void'
  );

  select acs_sc_impl_alias__delete(
    'PaymentGateway',
    'payflowpro',
    'info'
  );

  select acs_sc_binding__delete(
    'PaymentGateway',
    'payflowpro'
  );

  select acs_sc_impl__delete(
    'PaymentGateway',
    'payflowpro'
  );

drop table payflowpro_result_log;
