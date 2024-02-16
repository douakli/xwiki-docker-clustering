#!/bin/bash

# List of Solr cores. (See https://extensions.xwiki.org/xwiki/bin/view/Extension/Solr%20Search%20API#HManualinstall)
export FULL_CORES=xwiki
export MINIMAL_CORES="xwiki_extension_index xwiki_ratings xwiki_events"


install_cores () {
    # Install cores if they don't exist.
    # Usage: install_cores <TARGETS> <DATA_SOURCE>
    #
    # TARGETS: A list of core names passed as a single argument (Use quotes).
    # DATA_SOURCE: Path to the source data.

    for target in $1
        do
        if [ ! -d /var/solr/data/"$target" ]
            then
            cp -r $2 /var/solr/data/"$target"
        fi
    done
}

# Fix the /var/solr directory ownership when using volumes.
xwiki-docker-fix-var

# Initialize the /var/solr directory.
docker-entrypoint.sh

# Install XWiki Solr cores.
install_cores "$FULL_CORES" /usr/local/share/xwiki/solr/core
install_cores "$MINIMAL_CORES" /usr/local/share/xwiki/solr/core-minimal

# Give control to the real entrypoint.
exec docker-entrypoint.sh $@
