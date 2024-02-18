FROM httpd

RUN apt-get update && apt-get install patch

# Copy the entrypoint.
COPY xwiki-entrypoint.sh /usr/local/bin/

COPY patches /tmp/patches
RUN bash -c 'for patch in /tmp/patches/*.patch; do patch -p1 < $patch; done'

CMD "xwiki-entrypoint.sh"
