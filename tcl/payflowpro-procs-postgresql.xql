<?xml version="1.0"?>

<queryset>
  <rdbms>
    <type>postgresql</type>
    <version>7.1</version>
  </rdbms>

  <fullquery name="payflowpro.log_results.insert_transaction_record">
    <querytext>
      insert into payflowpro_result_log
      (transaction_id, txn_attempted_type, txn_attempted_time, txn_returned_type, errmsg, auth_code, avs_code_zip, avs_code_addr, amount)
      values
      (:transaction_id, :txn_attempted_type, current_timestamp, :txn_returned_type, :errmsg, :auth_code, :avs_code_zip, :avs_code_addr, :amount)
    </querytext>
  </fullquery>

</queryset>
