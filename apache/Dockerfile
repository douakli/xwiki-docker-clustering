FROM httpd

RUN apt-get update && apt-get install patch

COPY patches /tmp/patches
RUN bash -c 'for patch in /tmp/patches/*.patch; do patch -p1 < $patch; done'
