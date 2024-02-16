#!/bin/bash

# ---XWiki installation---

# Check if XWiki webapp is initialized
if [ ! -d "$CATALINA_HOME/webapps/xwiki/WEB-INF" ]
    then
    # Install XWiki.
    mkdir $CATALINA_HOME/webapps/xwiki
    mv "$CATALINA_HOME/webapps.dist/xwiki/"* "$CATALINA_HOME/webapps/xwiki"
fi


# ---JDBC Connector configuration---

# Add the selected JDBC connector
# Note: We always use the same jar file to make it possible to replace the connector.
cp "/usr/local/share/xwiki/$DB.jar" $CATALINA_HOME/webapps/xwiki/WEB-INF/lib/docker-jdbc-connector.jar

# Clean up previously inserted hibernate configurations. (Remove everyting *between* the INSERTION_LOCATION and INSERTION_END_LOCATION markers)
sed -i '/DOCKER: HIBERNATE_INSERTION_LOCATION/,/DOCKER: HIBERNATE_INSERTION_END_LOCATION/{//!d}' $CATALINA_HOME/webapps/xwiki/WEB-INF/hibernate.cfg.xml

# Apply the environment variables to the database
for var_name in DB_HOST DB_NAME DB_USER DB_PASSWORD
    do
    sed -i 's/$'"$var_name"'/'"${!var_name}"'/' /usr/local/share/xwiki/$DB.conf
done

# Apply the selected hibernate configuration. (Insert *after* the INSERTION_LOCATION marker)
sed -i '/DOCKER: HIBERNATE_INSERTION_LOCATION'"/r /usr/local/share/xwiki/$DB.conf" $CATALINA_HOME/webapps/xwiki/WEB-INF/hibernate.cfg.xml


# ---XWiki Superadmin configuration---

# Clean up previously inserted superadmin password. (Remove everyting *between* the INSERTION_LOCATION and INSERTION_END_LOCATION markers)
sed -i '/DOCKER: SUPERADMIN_PASSWORD_INSERTION_LOCATION/,/DOCKER: SUPERADMIN_PASSWORD_INSERTION_END_LOCATION/{//!d}' $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.cfg

# Apply the selected superadmin password.
if [ $XWIKI_SUPERADMIN_PASSWORD ]
    then
    # Writing the password to a file and making sed read from it makes escaping easier.
    echo 'xwiki.superadminpassword='"$XWIKI_SUPERADMIN_PASSWORD" > /tmp/superadmin
    sed -i '/DOCKER: SUPERADMIN_PASSWORD_INSERTION_LOCATION'"/r /tmp/superadmin" $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.cfg

    # Remember to remove the temp file.
    rm /tmp/superadmin
fi


# ---Solr configuration---

# Clean up previously inserted solr type configuration.
sed -i '/DOCKER: SOLR_TYPE_INSERTION_LOCATION/,/DOCKER: SOLR_TYPE_INSERTION_END_LOCATION/{//!d}' $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.properties

# Clean up previously inserted solr URL configuration.
sed -i '/DOCKER: SOLR_URL_INSERTION_LOCATION/,/DOCKER: SOLR_URL_INSERTION_END_LOCATION/{//!d}' $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.properties

# Insert new solr type configuration
echo "solr.type=$SOLR_TYPE" > /tmp/SolrType
sed -i '/DOCKER: SOLR_TYPE_INSERTION_LOCATION'"/r /tmp/SolrType" $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.properties
rm /tmp/SolrType

# Insert new solr url configuration.
if [ $SOLR_URL ]
    then
    # Write to a file for easier escaping.
    echo solr.remote.baseURL="$SOLR_URL" > /tmp/SolrURL
    sed -i '/DOCKER: SOLR_URL_INSERTION_LOCATION'"/r /tmp/SolrURL" $CATALINA_HOME/webapps/xwiki/WEB-INF/xwiki.properties

    # Remember to remove the temp file.
    rm /tmp/SolrURL
fi

# Exec replaces the running process with the given command.
exec catalina.sh run
