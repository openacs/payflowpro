<?xml version="1.0"?>

<queryset>

      <fullquery name="get_transactions">
          <querytext>
            select *
            from ${cleaned_package_key}_result_log
            order by txn_attempted_time"
          </querytext>
      </fullquery>

</queryset>
