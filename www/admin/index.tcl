ad_page_contract {

  Top page of transaction viewer

  @author Janine Sisk
  @creation-date  1/13/02
} {
} -properties {
  package_name
  context
  all_transactions:multirow
}

# get information about the gateway we're using;  this can stay generic
# by use of this method
#
set package_key [ad_conn package_key]
array set info [acs_sc_call PaymentGateway Info [list] $package_key]
set package_name $info(package_name)

# make sure user is authorized
ad_require_permission [ad_conn package_id] "admin"

# set context bar
set context [list]
