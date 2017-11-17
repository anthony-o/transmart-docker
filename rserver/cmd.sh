#!/bin/bash

set -x

# Copy all files of host pam.d locally
cp -ar /etc/pam.d.host/* /etc/pam.d/
cp /etc/pam.d/login /etc/pam.d/rstudio # In order to correctly make RStudio to log users using local PAM configuration - with Kerberos

# Merge some host groups (those defined in /etc/R_container/groups_to_merge )
if [ -f /etc/R_container/groups_to_merge ] ; then
    for GROUP in `cat /etc/R_container/groups_to_merge` ; do
        cat /etc/group.host | grep "$GROUP" >> /etc/group
    done
fi

# Add X11 support in R thanks to http://stackoverflow.com/a/1710952/535203 and https://gist.github.com/jterrace/2911875
Xvfb :0 -ac -screen 0 1960x2000x24 &

# Starting Rserve, inspired by https://github.com/tranSMART-Foundation/transmart-data/blob/2007abcf12b9d734b9b74348733e078e5ba014a2/R/rserve.conf.php#L25
R CMD Rserve --quiet --vanilla
# Start RStudio Server
# rstudio-server start # doesn't work in this CentOS container, fails with message "Reloading systemd:  Failed to get D-Bus connection: Operation not permitted" which points to https://github.com/docker/docker/issues/7459
#/etc/init.d/rstudio-server start

if [ -n "$(ls /etc/pki/ca-trust/source/anchors)" ] ; then
    # There are some custom certificates to import, thanks to https://unix.stackexchange.com/a/271076/29674
    update-ca-trust extract
fi

# Tail the RStudio server logs thanks to https://support.rstudio.com/hc/en-us/articles/200554766-RStudio-Server-Application-Logs
# tail -f /var/log/messages # Doesn't work: there is nothing at the 3 locations pointed by the article, they are at another locations http://stackoverflow.com/a/42511897/535203

exec /usr/sbin/init # To correctly start D-Bus thanks to https://forums.docker.com/t/any-simple-and-safe-way-to-start-services-on-centos7-systemd/5695/8