# tranSMART in a Docker architecture
Here are the specificities of the servers & tranSMART features activated for this project:
- Hosts are running on RedHat Enterprise Linux 7.3
- 5 servers:
  - PROD app : serving tranSMART application (`servers` Docker image + `front`)
  - PROD R : serving RServe + RStudio Serving (`rserver` Docker image)
  - TEST app
  - TEST R
  - DEV : serving tranSMART application 
- Kerberos plugin is used in order to authenticate users automatically with their Windows account
- OAuth plugin is used in order to use the APIs and RInterface from RStudio
- The `rserver` Docker image uses a `FROM centos:7` in order to be compatible with "Centrify" authentication system on RedHat in order for users that can be logged-in to the hosts can also login with their same account on the RStudio Server of the Docker Image
- Uses the Oracle version of tranSMART

## Architecture
On the hosts, there are 2 folders which will host all the data:
- `/var/local/transmart` - for all the data
- `/var/local/transmart-docker` - for the scripts of https://github.com/anthony-o/transmart-docker.git project

[`build-and-run.sh`](build-and-run.sh) script will build the required Docker images and launch them, using `docker-compose`.

Here is the explanation of the subfolders of the project:
- `/compose-files` - all the `docker-compose` files for the 5 different servers
- `/front` - the Docker image source of the "front" based on [httpd](https://hub.docker.com/_/httpd/) and required to secure the SolR admin console
- `/rserver` - the Docker image source of the RServe (containing all the needed packages for tranSMART) + RStudio Server
- `/server` - the Docker image source of tranSMART app. It downloads the required projects, compiles them and deploy transmartApp to a Tomcat when it is run.


## Installation
After installing `docker` & `docker-compose` on the host, simply execute this
```bash
cd /var/local
git clone --branch sanofi-release-16.1 https://github.com/anthony-o/transmart-docker.git
cd transmart-docker
```

Now download `oracle-instantclient12.1-devel-12.1.0.2.0-1.x86_64.rpm` and `oracle-instantclient12.1-basic-12.1.0.2.0-1.x86_64.rpm` from [Oracle website](http://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html) and move them to `/var/local/transmart-docker/rserver/`.

Configure the following 2 files if you want to run tranSMART application (with `<profile>` replaced by `dev`, `test` or `prod`):
- `/var/local/transmart/<profile>/.grails/transmartConfig/Config.groovy`
- `/var/local/transmart/<profile>/.grails/transmartConfig/DataSource.groovy`

And finally run (with `<profile>` replaced by `dev`, `test` or `prod`):
```bash
/var/local/transmart-docker/build-and-run.sh <profile>-app
```

To run the `rserver` image, execute:
```bash
/var/local/transmart-docker/build-and-run.sh <profile>-r
```