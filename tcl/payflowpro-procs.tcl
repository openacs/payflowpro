# some helper functions to simplify the main ones below

# Write the results of the current operation to the database.  If it fails,
# log it but don't let the user know about it.
ad_proc -private payflowpro.log_results {
    transaction_id
    txn_attempted_type
    txn_returned_type
    errmsg
    auth_code
    avs_code_zip
    avs_code_addr
    amount
} {
    @author Janine Sisk (janine@furfly.net)
} {
    db_transaction {
      db_dml insert_transaction_record ""
    } on_error {
      ns_log Error "Error inserting into payflowpro_result_log for transaction_id $transaction_id: $errmsg"
    }
}

# The heart of it all:  stub functions which can be used as a basis for a 
# new package - they all return something valid, and you can fill them in 
# one by one.  Many of the stubs are currently identical, as the whole 
# reason for their existence is in the gateway-specific stuff we're not
# implementing here.

ad_proc -public payflowpro.Authorize {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #

    # set up expected data structure
    set args [ns_set new]
    set cc_output [ns_set new]
    ns_set put $args "amount" [format %0.2f $amount]
    ns_set put $args "card-street" $billing_street
    ns_set put $args "card-zip" $billing_zip
    ns_set put $args "card-number" $card_number
    ns_set put $args "card-exp" $card_exp_month/$card_exp_year
    ns_set put $args "card-name" $card_name

    cc_send_to_server_21 "mauthonly" $args $cc_output

    set return_code_key ""
    set return_message ""
    set mstatus ""
    set merrmsg ""
    set merch_txn ""
    set aux_msg ""
    set auth_code ""
    set avs_code ""
    set avs_code_zip ""
    set avs_code_addr ""
    if { [ns_set size $cc_output] == 0 } {
      set return_code_key retry
    } else {
      set mstatus [ns_set get $cc_output "MStatus"]
      set merrmsg [ns_set get $cc_output "MErrMsg"]
      set merch_txn [ns_set get $cc_output "merch-txn"]
      set auth_code [ns_set get $cc_output "auth-code"]
      set avs_code [ns_set get $cc_output "avs-code"]
      set aux_msg [ns_set get $cc_output "aux-msg"]

      if { $mstatus == "failure-q-or-cancel" } {
        set return_code_key retry
        set return_message "$merrmsg $aux_msg"
      } elseif { $mstatus == "failure-bad-money" || $mstatus == "failure-hard" } {
        set return_code_key failure
        set return_message "$merrmsg $aux_msg"
      } else {
        # the only possibility left is success
        if { $avs_code_zip == "Y" && $avs_code_addr == "Y" } {
          set avs_code Y
          set return_code_key success
        } else {
          set return_code_key [ad_parameter -package_id [apm_package_id_from_key payflowpro] ActionOnPartialAVS "failure"]
          if { $return_code_key == "success" } {
            set avs_code Y
          } else {
            set avs_code N
            set return_message "Address Verification Failed"
          }
        }
      }
    }

    # 2. Insert into log table
    #
    payflowpro.log_results $merch_txn 'mauthonly' $mstatus $merrmsg $auth_code $avs_code_zip $avs_code_addr $amount

    # 3. Return result
    #
    set return_values(response_code) $return_code_key
    set return_values(reason) $return_message
    set return_values(transaction_id) $merch_txn
    return [array get return_values]
}

ad_proc -public payflowpro.ChargeCard {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # ChargeCard is a wrapper so we can present a consistent interface to
    # the end caller.  It will just pass on it's parameters to PostAuth,
    # AuthCapture or Charge, whichever is appropriate for the implementation
    # at hand.  Here, we are doing nothing.

    return [payflowpro.PostAuth $transaction_id $amount]
}

# It's unlikely that a Return will need all this but I can imagine that
# one of the ultra-cheap services might want to validate the card again,
# giving them another chance to catch a bad card.
ad_proc -public payflowpro.Return {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #

    # set up expected data structure
    set args [ns_set new]
    set cc_output [ns_set new]
    ns_set put $args "order-id" $transaction_id
    ns_set put $args "amount" [format %0.2f $amount]

    cc_send_to_server_21 "return" $args $cc_output

    set return_code_key ""
    set return_message ""
    set mstatus ""
    set merrmsg ""
    set merch_txn ""
    set aux_msg ""
    set auth_code ""
    if { [ns_set size $cc_output] == 0 } {
      set return_code_key retry
    } else {
      set mstatus [ns_set get $cc_output "MStatus"]
      set merrmsg [ns_set get $cc_output "MErrMsg"]
      set merch_txn [ns_set get $cc_output "merch-txn"]
      set auth_code [ns_set get $cc_output "auth-code"]
      set aux_msg [ns_set get $cc_output "aux-msg"]

      if { $mstatus == "failure-q-or-cancel" } {
        set return_code_key retry
      } elseif { $mstatus == "failure-bad-money" || $mstatus == "failure-hard" } {
        set return_code_key failure
        set return_message "$merrmsg $aux_msg"
      } else {
        # the only possibility left is success
        set return_code_key success
      }
    }

    # 2. Insert into log table
    #
    payflowpro.log_results $merch_txn 'return' $mstatus $merrmsg $auth_code "" "" $amount

    # 3. Return result
    #
    set return_values(response_code) $return_code_key
    set return_values(reason) $return_message
    set return_values(transaction_id) $merch_txn
    return [array get return_values]
}

# See comment on Return
ad_proc -public payflowpro.Void {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #

    # set up expected data structure
    set args [ns_set new]
    set cc_output [ns_set new]
    ns_set put $args "order-id" $transaction_id

    cc_send_to_server_21 "void" $args $cc_output

    set return_code_key ""
    set return_message ""
    set mstatus ""
    set merrmsg ""
    set merch_txn ""
    set aux_msg ""
    set auth_code ""
    if { [ns_set size $cc_output] == 0 } {
      set return_code_key retry
    } else {
      set mstatus [ns_set get $cc_output "MStatus"]
      set merrmsg [ns_set get $cc_output "MErrMsg"]
      set merch_txn [ns_set get $cc_output "merch-txn"]
      set auth_code [ns_set get $cc_output "auth-code"]
      set aux_msg [ns_set get $cc_output "aux-msg"]

      if { $mstatus == "failure-q-or-cancel" } {
        set return_code_key retry
      } elseif { $mstatus == "failure-bad-money" || $mstatus == "failure-hard" } {
        set return_code_key failure
        set return_message "$merrmsg $aux_msg"
      } else {
        # the only possibility left is success
        set return_code_key success
      }
    }

    # 2. Insert into log table
    #
    payflowpro.log_results $merch_txn 'void' $mstatus $merrmsg $auth_code "" "" $amount

    # 3. Return result
    #
    set return_values(response_code) $return_code_key
    set return_values(reason) $return_message
    set return_values(transaction_id) $merch_txn
    return [array get return_values]
}

ad_proc -public payflowpro.Info {
} {
    @author Janine Sisk (janine@furfly.net)
} {
    set info(package_key) payflowpro
    set info(version) 1.0
    set info(package_name) "PayFlowPro"
    set info(cards_accepted) [ad_parameter -package_id [ad_conn package_id] CreditCardsAccepted ""]
    set info(success) [nsv_get payment_gateway_return_codes success]
    set info(failure) [nsv_get payment_gateway_return_codes failure]
    set info(retry) [nsv_get payment_gateway_return_codes retry]
    set info(not_supported) [nsv_get payment_gateway_return_codes not_supported]
    set info(not_implemented) [nsv_get payment_gateway_return_codes not_implemented]

    return [array get info]
}

# These stubs aren't exposed via the API - they are called only by ChargeCard.

ad_proc -private payflowpro.PostAuth {
    transaction_id
    {amount ""}
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #

    # set up expected data structure
    set args [ns_set new]
    set cc_output [ns_set new]
    ns_set put $args "order-id" $transaction_id
    ns_set put $args "amount" [format %0.2f $amount]

    cc_send_to_server_21 "postauth" $args $cc_output

    set return_code_key ""
    set return_message ""
    set mstatus ""
    set merrmsg ""
    set merch_txn ""
    set aux_msg ""
    set auth_code ""
    if { [ns_set size $cc_output] == 0 } {
      set return_code_key retry
    } else {
      set mstatus [ns_set get $cc_output "MStatus"]
      set merrmsg [ns_set get $cc_output "MErrMsg"]
      set merch_txn [ns_set get $cc_output "merch-txn"]
      set auth_code [ns_set get $cc_output "auth-code"]
      set aux_msg [ns_set get $cc_output "aux-msg"]

      if { $mstatus == "failure-q-or-cancel" } {
        set return_code_key retry
      } elseif { $mstatus == "failure-bad-money" || $mstatus == "failure-hard" } {
        set return_code_key failure
        set return_message "$merrmsg $aux_msg"
      } else {
        # the only possibility left is success
        set return_code_key success
      }
    }

    # 2. Insert into log table
    #
    payflowpro.log_results $merch_txn 'postauth' $mstatus $merrmsg $auth_code "" "" $amount

    # 3. Return result
    #
    set return_values(response_code) $return_code_key
    set return_values(reason) $return_message
    set return_values(transaction_id) $merch_txn
    return [array get return_values]
}

ad_proc -private payflowpro.AuthCapture {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #
    # Not implemented in this stub.

    # 2. Insert into log table
    #
    # Not implemented in this stub.

    # 3. Return result
    #
    # The result which comes back from the gateway will be looked at and then
    # the most appropriate of our canned return codes will be used.  This 
    # needs to be done in context, so it will be done in each function instead
    # of being split out on its own.
    set return_values(response_code) [nsv_get payment_gateway_return_codes not_implemented]
    set return_values(reason) ""
    set return_values(transaction_id) ""
    return [array get return_values]
}

ad_proc -private payflowpro.Charge {
    transaction_id
    amount
    card_type
    card_number
    card_exp_month
    card_exp_year
    card_name
    billing_street
    billing_city
    billing_state
    billing_zip
    billing_country
} {
    @author Janine Sisk (janine@furfly.net)
} {
    # 1. Send transaction off to gateway
    #
    # Not implemented in this stub.

    # 2. Insert into log table
    #
    # Not implemented in this stub.

    # 3. Return result
    #
    # The result which comes back from the gateway will be looked at and then
    # the most appropriate of our canned return codes will be used.  This 
    # needs to be done in context, so it will be done in each function instead
    # of being split out on its own.
    # 
    # In particular, here we will need to check a package parameter to find
    # out whether they can be considered authorized if they fail AVS
    set return_values(response_code) [nsv_get payment_gateway_return_codes not_implemented]
    set return_values(reason) ""
    set return_values(transaction_id) ""
    return [array get return_values]
}
