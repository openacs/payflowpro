ad_page_contract {

  Top page of transaction viewer

  @author Janine Sisk
  @creation-date  1/13/02
} {
} -properties {
  package_name
  context_bar
  all_transactions:multirow
}

# get information about the gateway we're using;  this can stay generic
# by use of this method
#
set package_key [ad_conn package_key]
array set info [acs_sc_call PaymentGateway Info [list] $package_key]
set package_name $info(package_name)
set cleaned_package_key [apm_tcl_or_sql_name_from_package_key $package_key]

# make sure user is authorized
ad_require_permission [ad_conn package_id] "admin"

# set context bar
set context_bar [ad_context_bar]

# get data from table
db_multirow all_transactions get_transactions ""

# This page will eventually allow the user to enter a date range and search
# for keywords, but this will do for now
