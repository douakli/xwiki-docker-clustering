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

XWiki can then be accessed from http://localhost:8002/

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
We however did not manage to get multiple instances of XWiki synchronized and clustered.

## Features
The docker-compose file uses the "profiles" attribute makes a container start only if one of the listed profiles is active.
We use this mechanism to decide which database container to start.

For a minimal configuration using only apache and tomcat: In the `.env` file, set `DB_TYPE=hsqldb` and `SOLR_TYPE=embedded`.

On first startup, the different containers will populate the `data/` directory. Note that switching database **after** the `data/`
directory is initialized is **not recommended**. No data will be transfered from the old database to the new one. If you need to change
database, then reinitialize XWiki by removing the `data/` directory entirely.

Finally, our tomcat Docker image handles environment variables and writes the content to the various configuration file using `sed` and marked locations.

## Discussion
### Tomcat
Setting up the Tomcat image for XWiki usually involves tweaking configuration files manually. Because there are so many configuration options, we only handle
the most important ones. We decided to use patches to edit the configuration files in an easy to write way, avoiding as much as possible using sed or regex.
We also use these patches to help us when we do have to use sed to insert configuration from environment variables.

We implemented a custom entrypoint that takes care of initializing the data directory only if it has not been initialized before. It also handles editing configuration
files in a non destructive way. The user still needs to be able to configure their XWiki installation, and they can do so through the `data/tomcat` directory.
If they want to override a dynamically inserted configuration, one can simply remove the instertion markers.

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
We technically did not need a reverse proxy at this point of the project, but it is required for the next step: enabling Clustering.
We started setting up all the requirements for that goal, including a load balancing reverse proxy, here Apache httpd.

To do so, we followed the following XWiki documentation: https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Clustering/
and https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Clustering/DistributedEventClusterSetup/

The process involves:
* Making all the instances (in our case: tomcat containers) use the same database. (OK)
* Making all the instances share their attachment store (data/tomcat/data/store/file) (OK)
* Making each instance have their own private volume for permanent storage of everything else. (data/tomcat) (TODO)
* Making all the instances share the events through remote observation \[We use a virtual network for all the instances, and they communicate through udp over multicast, which allow them to discover each other] (OK)
* Making all the instances use the same Solr instance. \[Not mandatory, but makes more sense/ is more efficient] (OK)
* Add a Load balancer to lead user to the different instances in the cluster (OKish, just need to add an entry for the extra instances hostnames)

For our usage of httpd, we mainly want to edit `httpd.conf`.
