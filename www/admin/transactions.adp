<master>
<property name="title">View @package_name@ Transactions</property>
<property name="context">@context@</property>

All transactions which have been processed via @package_name@:
<p>
<table border=1>
  <tr>
    <td>transaction_id</td>
    <td>tran type sent</td>
    <td>tran time</td>
    <td>tran type returned</td>
    <td>error msg</td>
    <td>auth code</td>
    <td>AVS (zip)</td>
    <td>AVS (addr)</td>
    <td>amount</td>
  </tr>

  <multiple name="all_transactions">
    <tr>
      <td>@all_transactions.txn_attempted_time@</td>
      <td>@all_transactions.txn_attempted_type@</td>
      <td>@all_transactions.transaction_id@</td>
      <td>@all_transactions.txn_returned_type@</td>
      <td>@all_transactions.errmsg@</td>
      <td>@all_transactions.auth_code@</td>
      <td>@all_transactions.avs_code_zip@</td>
      <td>@all_transactions.avs_code_addr@</td>
      <td>@all_transactions.amount@</td>
    </tr>
  </multiple>
</table>
