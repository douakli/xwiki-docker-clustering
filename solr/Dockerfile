# ---------- HELPER STAGE ----------
# This helper stage compiles the xwiki-docker-fix-var program and downloads the cores.
FROM solr as prepare

USER root

# Install gcc and make.
RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y wget unzip

# Download solr cores
RUN mkdir -p /tmp/xwiki-share/solr

RUN wget -O /tmp/core.zip https://maven.xwiki.org/releases/org/xwiki/platform/xwiki-platform-search-solr-server-core/16.0.0/xwiki-platform-search-solr-server-core-16.0.0.jar
RUN wget -O /tmp/core-minimal.zip https://maven.xwiki.org/releases/org/xwiki/platform/xwiki-platform-search-solr-server-core-minimal/16.0.0/xwiki-platform-search-solr-server-core-minimal-16.0.0.zip

RUN unzip /tmp/core.zip -d /tmp/xwiki-share/solr/core
RUN unzip /tmp/core-minimal.zip -d /tmp/xwiki-share/solr/core-minimal

# Add the source code to the container.
COPY xwiki-docker-fix-var /tmp/xwiki-docker-fix-var
WORKDIR /tmp/xwiki-docker-fix-var

# Compile the setuid program.
RUN make -j

# ---------- MAIN ----------
# This main image is a wrapper around the solr docker image.
# The goal is to make sure the /var/solr directory has correct permissions.
# Note: XWiki is not currently compatible with Solr 9.
FROM solr
# Switch to root to be able to install our custom scripts.
USER root:root

# Install our new entrypoint.
COPY xwiki-docker-entrypoint.sh /usr/local/bin/

# Install our setuid script.
COPY --from=prepare /tmp/xwiki-docker-fix-var/bin/xwiki-docker-fix-var /usr/local/bin/xwiki-docker-fix-var
# Set the setuid bit on our script, allows it to run as root.
RUN chmod +s /usr/local/bin/xwiki-docker-fix-var

# Install our cores
COPY --from=prepare /tmp/xwiki-share /usr/local/share/xwiki

# Keep a backup of /var/solr.
COPY --from=prepare /var/solr /usr/local/share/xwiki/var/solr

# Switch back to the solr user.
USER $SOLR_UID

# Use our new entrypoint.
ENTRYPOINT ["xwiki-docker-entrypoint.sh"]
CMD ["solr-foreground"]
