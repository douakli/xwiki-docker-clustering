# ---------- HELPER STAGE ----------
# This helper stage compiles the setuid program.
FROM ubuntu as build-setuid

# Install gcc and make.
RUN apt-get update
RUN apt-get install -y build-essential

# Add the source code to the container.
COPY setuid /tmp/setuid
WORKDIR /tmp/setuid

# Compile the setuid program.
RUN make -j

# ---------- MAIN ----------
# This main image is a wrapper around the solr docker image.
# The goal is to make sure the /var/solr directory has correct permissions.
FROM solr

# Switch to root to be able to install our custom scripts.
USER root:root

# RUN mkdir /mnt/data

# Install our new entrypoint.
COPY xwiki-docker-entrypoint.sh /usr/local/bin/

#COPY xwiki-docker-fix-var /usr/local/bin/

# Install our setuid script.
COPY --from=build-setuid /tmp/setuid/bin/xwiki-docker-fix-var /usr/local/bin/xwiki-docker-fix-var
# Set the setuid bit on our script, allows it to run as root.
RUN chmod +s /usr/local/bin/xwiki-docker-fix-var

# Switch back to the solr user.
USER $SOLR_UID

# Use our new entrypoint.
ENTRYPOINT ["xwiki-docker-entrypoint.sh"]
CMD ["solr-foreground"]
