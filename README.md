# Dockerizing XWiki
This project provides a docker-compose set-up for XWiki with different configuration settings.

## Authors
* Achille Masson
* Dorian Ouakli
* Rinsai Rossetti
* Dylan Sebih

## Usage
This repository provides a default configuration, that can be changed in the `.env` file.

Starting XWiki:
```
# docker compose up
```
or
```
# docker-compose up
```

XWiki can then be accessed from http://localhost:8080/

By default, there is no administrator account set up in the instance.
One can register and use a standard user account to edit pages, but will not have access to the administration page.

To have administrator permissions, it is recommended to run the XWiki with a superadmin password set up temporarily,
Create an administrator account with administrator permissions, and then remove the superadmin password. Once
that is done, one can simply use the administrator account to perform administrative tasks on their wiki.

Docker and docker-compose are required to run the project. It seems like some features of Docker Compose
we use have been introduced relatively recently. To test our project, we used the following Docker and Docker Compose
versions:

```
$ docker version
Client:
 Version:           24.0.5
 API version:       1.43
 Go version:        go1.21.3
 Git commit:        ced0996600
 Built:             Fri Oct 27 18:36:31 2023
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          24.0.5
  API version:      1.43 (minimum version 1.12)
  Go version:       go1.21.3
  Git commit:       4ffc61430bbe6d3d405bdf357b766bf303ff3cc5
  Built:            Fri Oct 27 19:48:19 2023
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v1.7.1
  GitCommit:        2806fc1057397dbaeefbea0e4e17bddfbd388f38
 runc:
  Version:          1.1.7
  GitCommit:        4ffc61430bbe6d3d405bdf357b766bf303ff3cc5
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad007797e0dcd8b7126f27bb87401d224240
```

```
$ docker compose version
Docker Compose version v2.20.3
```

If you have trouble running the project, please consider running
with a more recent version of Docker/Docker Compose.


## Overview
XWiki is a Wiki engine implemented as a Java webapp.
XWiki requires a servlet engine such as Tomcat or Jetty to run.
We decided to use Tomcat for this dockerization.

This is technically all that is *required* for XWiki to run.
XWiki uses a database and a Solr indexer, but there are embedded versions
contained in the webapp's WAR.

These defaults are fine for a test environment, but are not ideal for a production
setting, where we need to be able to monitor and backup the data from the different
elements.

XWiki embeds HSQLDB, but supports many databases. This dockerization
supports using HSQLDB, MariaDB, MySQL and PostgreSQL.

XWiki embeds Solr 8. We provide a container for Solr 9.

Using external Solr and Database is also necessary for clustering of XWiki.

## Features
The docker-compose file uses the "profiles" attribute makes a container start only if one of the listed profiles is active.
We use this mechanism to decide which database container to start.

For a minimal configuration using only apache and tomcat: In the `.env` file, set `DB_TYPE=hsqldb` and `SOLR_TYPE=embedded`.

On first startup, the different containers will populate the volumes. Note that switching database **after** the volumes
are initialized is **not recommended**. No data will be transfered from the old database to the new one. If you need to change
database, then reinitialize XWiki by removing the volumes entirely.

Finally, our tomcat Docker image handles environment variables and writes the content to the various configuration file using `sed` and marked locations.

## Discussion
### Tomcat
Setting up the Tomcat image for XWiki usually involves tweaking configuration files manually. Because there are so many configuration options, we only handle
the most important ones. We decided to use patches to edit the configuration files in an easy to write way, avoiding as much as possible using sed or regex.
We also use these patches to help us when we do have to use sed to insert configuration from environment variables.

We implemented a custom entrypoint that takes care of initializing the data directory only if it has not been initialized before. It also handles editing configuration
files in a non destructive way. The user still needs to be able to configure their XWiki installation, and they can do so through the volume, or by running an interactive
session in the container with `docker compose exec -it node1 /bin/bash` for instance.
If they want to override a dynamically inserted configuration, one can simply remove the insertion markers.

To help us during the configuration, we followed XWiki's documentation: https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Configuration
and https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Installation/InstallationWAR/InstallationTomcat/

### Solr
Solr is a mostly straightforward installation. XWiki needs some "Solr Cores" to be preinstalled, this is done by simply unpacking zip files in the Solr directory.
However, we ran into an issue when using a volume to permanently store the Solr cores. Solr would complain that the `/var/solr` directory was not writeable
by an user of uid 8983. This is because Solr runs as an unprivileged user in the Solr container. But the volume, created by the docker daemon, is owned by root.

We thought we could simply fix this issue by switching to root in the Dockerfile temporarily to fix the permissions and then switch back to the solr user.
Unfortunately, Docker volumes are created at runtime, this means that we need to either have a privileged entrypoint that drops privileges after fixing
the docker volume. Or we could have an entrypoint that escalates privileges to fix the docker volume, while still being started as a solr user.

We decided to do the latter. By setting the setuid bit on a root-owned script whose sole job is to fix the `/var/solr` directory,
and running that script from the entrypoint, we thought we could escalate temporarily. We learned however that this is not possible
for a script (see http://www.faqs.org/faqs/unix-faq/faq/part4/section-7.html). For this method to work, the setuid bit must
be applied to a binary. This is why we wrote a small C program that does the same thing.

### httpd (Apache)
A reverse proxy is necessary to set up the load balancing of our cluster. The user accesses a single URL, but is redirected
to a specific node.
To set up the reverse proxy, we followed the following XWiki documentation: https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Clustering/
and https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Clustering/DistributedEventClusterSetup/

### Clustering
The configurability of our tomcat image facilitates some of the steps involved in clustering XWiki.
First of all, the database must be shared among the different members of the cluster.
This means that clustering is not compatible with hsqldb. We simply configure all the tomcat containers with the same database connection.
The Solr instance can be shared similarly.

However, connecting the different nodes to the same database is not enough.
XWiki has caches. This means that the different nodes must be able to communicate directly to each other to invalidate and update
the different caches. This communication is already supported by XWiki, and uses JGroups. JGroups is a generic protocol that
is usually transported over multicast UDP. However we can't use multicast in docker networks. The nodes can't discover each other.

To allow the nodes to discover each other, we decided to use the TCPGOSSIP discovery protocol, which uses a (or multiple) central server
(The gossip router) to gather the nodes.

Finally, we need to share the attachments volume across the different nodes. In a distributed setup, a network filesystem would work.

## Walkthrough
Let's go through the setps to configure and use this dockerized version of XWiki.

### Configuration
The configuration is mainly done through the `.env` file.
This file sets up environment variables prior to the interpretation of the `docker-compose.yml`.
This allows for more control over the project.

The first step is to uncomment the `XWIKI_SUPERADMIN_PASSWORD` line and to set a superadmin password.
This password is temporary and will let us set up an actual Admin user later in the walkthrough.

Then we can switch database if we wish to, we can use mysql or mariadb instead of postgresql.
We can switch to hsqldb if we plan to use only one node in our cluster, which would just be a normal xwiki instance.

Then we can decide if Solr should be embedded or remote. XWiki recommends to use a remote Solr when Clustering, so this
is the default.
In this example, we will stick to the defaults.

Finally, we can decide on how many nodes we want in our cluster.
This configuration is Unfortunately done through the `docker-compose.yml` because it involves
creating an arbitrary amount of containers with custom parameters that can be configured.

Find the `# ---XWiki Nodes---` in `docker-compose.yml`.
If you wish to remove nodes, simply remove or comment the node\<N> container out.
If you wish to add nodes, use the following template:

```yaml
    node999:
        <<: *tomcat # Fragment syntax for common configuration.
        volumes:
            - node999:$TOMCAT_XWIKI_PATH
            - tomcat-attachments:/usr/local/tomcat/webapps/xwiki/data/store/file # Shared volume
        environment:
            NODE_NAME: "node999"
```

Note: the `NODE_NAME` is what is reused in the apache(httpd) configuration and what is in the footer of wiki pages.

Once we added the new container, we need to update related parts of the docker container:
* In `# ---Load balancer---`, find the environment variable `NODES` and update the list according to your changes.
* Find the global **volume** definitions `# ---Global definitions---` and update the volumes list.

### Running XWiki
We can start our XWiki cluster with `docker-compose up`.
There are many container and they are very verbose, if we need to troubleshoot issues, it is better to look at
container logs individually with `docker compose logs <container>`

# TODO: Insert docker ps
Once the containers started, we can access XWiki throught `http://localhost:8080`
XWiki sets up some things and the initialization process might take some time.
# TODO: Insert initialization

Once the initialization is done, we land on a not found page, this is because the Home page got installed during the initialization phase,
we just need to refresh.
# TODO: Insert not found.
# TODO: Insert Home.

Notice how we can see on which node we have been sent to by the load balancer by reading the footer. Here, we are on node1.

### Setting up an Admin account
Let's login as `superadmin`, the user we created a password for in the configuration step.
Click on the top right burger menu and click **Log-in**.

The username is `superadmin` and the password is the one you set.

Once logged-in, go back in the burger menu and click "Administer Wiki".

From there, click "Users & Rights" then Users.

Click "Create User"

Fill in the form for your Admin user (not necessarily called admin) and click create.

Then move to Groups, below Users.
Find the `XWikiAdminGroup` and click "Edit".

Select the Admin user you just created and click "Add". You can now close the form.

We can now log-out from the superadmin user and stop XWiki by pressing CTRL+C in the terminal where we started it.

Edit the `.env` file again, and comment the superadmin password line. We will use the admin account from now on for administrative tasks.

Start XWiki again with `docker compose up`

Now for the clustering, the user sessions are distributed. One can use a private window and see the difference in the footer.

**Please see the screenshots in the `images` directory.
