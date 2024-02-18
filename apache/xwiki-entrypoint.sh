#!/bin/bash

# Clean up previous config.
sed -i '/DOCKER: BALANCE_MEMBERS_INSERTION_LOCATION/,/DOCKER: BALANCE_MEMBERS_INSERTION_END_LOCATION/{//!d}' /usr/local/apache2/conf/httpd.conf

# List balance members
for node in $NODES
    do
    echo BalancerMember ajp://$node:8009 route=jvm-$node >> /tmp/balanceMembers
done

# Insert new configuration.
sed -i '/DOCKER: BALANCE_MEMBERS_INSERTION_LOCATION'"/r /tmp/balanceMembers" /usr/local/apache2/conf/httpd.conf

exec httpd-foreground
