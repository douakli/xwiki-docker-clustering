#!/bin/bash

# Fix the /var/solr directory ownership when using volumes.
xwiki-docker-fix-var

# TODO: Install XWiki Solr cores.

# Give control to the real entrypoint.
exec docker-entrypoint.sh $@
