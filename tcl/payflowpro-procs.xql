<?xml version="1.0"?>

<queryset>

      <fullquery name="payflowpro.log_results.insert_transaction_record">
          <querytext>
            insert into payflowpro_result_log
            (transaction_id, txn_attempted_type, txn_attempted_time, txn_returned_type, errmsg, auth_code, avs_code_zip, avs_code_addr, amount)
            values
            (:transaction_id, :txn_attempted_type, sysdate, :txn_returned_type, :errmsg, :auth_code, :avs_code_zip, :avs_code_addr, :amount)
          </querytext>
      </fullquery>

</queryset>
