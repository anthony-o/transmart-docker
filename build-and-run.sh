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

# Build R server image (Sanofi specific: need a Rserve image based on CentOS in order for Centrify - auth mechanism - to be installed and work correctly)
cd $BASE_SCRIPT_DIR/rserver
PREVIOUS_TRANSMART_RSERVER_IMAGE_ID=$(docker images --quiet transmart_rserver || echo "")
docker build --build-arg https_proxy=$https_proxy_IN_CONTAINER --build-arg http_proxy=$http_proxy_IN_CONTAINER -t transmart_rserver ./

PREVIOUS_TRANSMART_RSERVER_BASE_IMAGE_ID=$(cat /var/local/transmart/built_transmart_rserver_base_image_id || echo "")
CURRENT_TRANSMART_RSERVER_BASE_IMAGE_ID=$(docker images --quiet transmart_rserver)
if [ "$PREVIOUS_TRANSMART_RSERVER_BASE_IMAGE_ID" != "$CURRENT_TRANSMART_RSERVER_BASE_IMAGE_ID" ] ; then
    # The previous transmart_rserver docker image does not correspond to current build, let's continue the build and install Centrify tools - Sanofi specific (thanks to https://github.com/docker/docker/issues/14080#issuecomment-269460330 idea)
    if [ ! -f /cdc/centrifydc-install.sh ] ; then
        echo "Must mount /cdc first (this must point to Centrify installation tools). Call GAHS or Analytics Platforms and Services if you don't know what it is" >&2
        exit 1
    fi
    docker rm transmart_rserver_build || echo "'transmart_rserver_build' container does not exist, that's normal."
    docker run -it --name transmart_rserver_build -v /cdc:/cdc transmart_rserver /cdc/centrifydc-install.sh -r AMER
    docker commit '--change=CMD ["/usr/local/bin/cmd.sh"]' transmart_rserver_build transmart_rserver
    docker rm transmart_rserver_build
    echo $CURRENT_TRANSMART_RSERVER_BASE_IMAGE_ID | dzdo tee /var/local/transmart/built_transmart_rserver_base_image_id
else
    docker tag $PREVIOUS_TRANSMART_RSERVER_IMAGE_ID transmart_rserver
fi

docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml build $*
docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml rm -f $*
docker-compose -f $BASE_SCRIPT_DIR/transmart-$TARGET_ENV.yml up -d $*
