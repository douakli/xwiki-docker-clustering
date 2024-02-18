# ---------- HELPER STAGE ----------
# We do not want to install unnecessary packages on the final image.
# This intermediary stage will download and patch the war.
FROM alpine as download

# Download XWiki.
WORKDIR /tmp/xwiki-webapp
RUN wget https://nexus.xwiki.org/nexus/service/local/repositories/releases/content/org/xwiki/platform/xwiki-platform-distribution-war/16.0.0/xwiki-platform-distribution-war-16.0.0.war -O xwiki.war

# Unpack the XWiki WAR manually so that we can apply patches (default configuration).
RUN unzip xwiki.war
RUN rm xwiki.war

# Download XWiki Standard Flavor (Optional)
RUN wget https://nexus.xwiki.org/nexus/service/local/repositories/releases/content/org/xwiki/platform/xwiki-platform-distribution-flavor-xip/16.0.0/xwiki-platform-distribution-flavor-xip-16.0.0.xip -O flavor.xar

# Unpack the XWiki Standard Flavor for faster first run. (Otherwise, XWiki would download the flavor at runtime)
RUN mkdir -p data/extension
RUN unzip flavor.xar -d data/extension/repository
RUN rm flavor.xar

# Apply patches.
RUN apk add patch
COPY patches/xwiki /tmp/xwiki-patches
RUN for patchFile in /tmp/xwiki-patches/*; do patch -p1 < $patchFile; done

# Set up /usr/local/share directory (files needed by our entrypoint at runtime).
COPY share /tmp/xwiki-share

# Add the JDBC connectors.
WORKDIR /tmp/xwiki-share
# NOTE: HSQLDB
RUN wget https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.7.2/hsqldb-2.7.2.jar -O hsqldb.jar

# NOTE: MariaDB
RUN wget https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.2/mariadb-java-client-3.3.2.jar -O mariadb.jar

# NOTE: PostgreSQL
RUN wget https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.1/postgresql-42.7.1.jar -O postgresql.jar

# NOTE: MySQL
RUN wget https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.3.0/mysql-connector-j-8.3.0.jar -O mysql.jar

# ---------- MAIN ----------
# Set up the final image.
# XWiki is not compatible with tomcat 10, this is why we use tomcat 9.
FROM tomcat:9

RUN apt-get update && apt-get install -y patch iproute2

COPY patches/tomcat /tmp/tomcat-patches
RUN for patchFile in /tmp/tomcat-patches/*; do patch -p1 < $patchFile; done

# Copy the XWiki webapp in the webapps.dist/xwiki directory
# Note: We do this in webapps.dist/ and not webapps/ because webapps will have user data that needs to be conserved.
# The entrypoint will copy the directory from webapps.dist if the one in webapps is not already initialized.
COPY --from=download /tmp/xwiki-webapp $CATALINA_HOME/webapps.dist/xwiki

# Copy the files needed by the entrypoint.
COPY --from=download /tmp/xwiki-share /usr/local/share/xwiki

# Copy the entrypoint.
COPY entrypoint.sh /usr/local/bin/

# Provide a default database.
# Note: hsqldb database are hosted within the webapp, we do not need to provide an other container or a connection for it to work.
ENV DB="hsqldb"

# Provide a default Solr configuration.
ENV SOLR_MODE="embedded"

# By default, run our entrypoint.
CMD "entrypoint.sh"
