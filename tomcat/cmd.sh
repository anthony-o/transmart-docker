#!/bin/bash

if [ -z "`ls $CATALINA_HOME/webapps`" ] ; then
    cp -ra $CATALINA_HOME/webapps.orig/* $CATALINA_HOME/webapps
fi

catalina.sh run