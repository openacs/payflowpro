--  This is an implementation of the PaymentGateway service contract for
--  Verisign's PayFlow Pro payment service

  select acs_sc_impl__new(
	   'PaymentGateway',               	-- impl_contract_name
           'payflowpro',                        -- impl_name
	   'payflowpro'                         -- impl_owner_name
  );

  select acs_sc_impl_alias__new(
           'PaymentGateway',			-- impl_contract_name
           'payflowpro',			-- impl_name
	   'Authorize', 			-- impl_operation_name
	   'payflowpro.Authorize', 		-- impl_alias
	   'TCL'    				-- impl_pl
  );

  select acs_sc_impl_alias__new(
           'PaymentGateway',			-- impl_contract_name
           'payflowpro',			-- impl_name
	   'ChargeCard', 			-- impl_operation_name
	   'payflowpro.ChargeCard', 	        -- impl_alias
	   'TCL'    				-- impl_pl
  );

  select acs_sc_impl_alias__new(
           'PaymentGateway',			-- impl_contract_name
           'payflowpro',			-- impl_name
	   'Return', 				-- impl_operation_name
	   'payflowpro.Return', 		-- impl_alias
	   'TCL'    				-- impl_pl
  );

  select acs_sc_impl_alias__new(
           'PaymentGateway',			-- impl_contract_name
           'payflowpro',			-- impl_name
	   'Void', 				-- impl_operation_name
	   'payflowpro.Void', 		        -- impl_alias
	   'TCL'    				-- impl_pl
  );

  select acs_sc_impl_alias__new(
           'PaymentGateway',			-- impl_contract_name
           'payflowpro',			-- impl_name
	   'Info', 				-- impl_operation_name
	   'payflowpro.Info', 		        -- impl_alias
	   'TCL'    				-- impl_pl
  );

-- Add the binding

  select acs_sc_binding__new (
            'PaymentGateway',
            'payflowpro'
        );

-- NOTE - this stuff is here because the naming is instance-specific.  I'm
-- not sure that is correct;  it would be better if it could be part of the
-- PaymentGateway specification.  However, for the purposes of an initial
-- release this will do.

-- In addition to all the usual service contract definitions, we also need
-- a table which will be used to log results of all our operations.  The
-- table is modeled after ec_cybercash_log in the old 3.x ecommerce code.
-- I tried to simplify it quite a bit, which means it will probably need more
-- columns added to it when it is actually being used in real life.
--
create table payflowpro_result_log (
  transaction_id            varchar(20),
  txn_attempted_type        varchar(25),
  txn_attempted_time        timestamp,
  txn_returned_type         varchar(25),
  errmsg                    varchar(200),
  auth_code                 varchar(25),
  avs_code_zip              varchar(3),
  avs_code_addr             varchar(3),
  amount                    numeric
);
