#!/bin/bash

set -x
set -e

BASE_SCRIPT_DIR="$(readlink -f `dirname $0`)"

TARGET_ENV=$1

shift

# Configure proxy for containers
PROXYS_IN_CONTAINER=""
for PROXY_VAR in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ; do
    PROXY_VALUE=${!PROXY_VAR}
    
    if [ -n "$PROXY_VALUE" ] ; then
        # Proxy is set, let's set it to docker containers
        if [[ "$PROXY_VALUE" =~ //localhost:([:digit:]*|$) ]] ; then
            # Proxy is set at localhost, replace it
            PROXY_VALUE=$(echo "$PROXY_VALUE" | sed -e"s/localhost/`ifconfig | grep docker0 -A 1 | awk '/inet/ { print $2}'`/")
        fi
        # set dynamic variable thanks to http://stackoverflow.com/a/18124325/535203
        declare -x ${PROXY_VAR}_IN_CONTAINER=$PROXY_VALUE
    fi
done

docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml build $*
docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml rm -f $*
docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml up -d $*
