#!/bin/bash

set -x
set -e

STARTTIME=$(date +%s)

BASE_SCRIPT_DIR="$(readlink -f `dirname $0`)"

TARGET_ENV=$1
COMPOSE_FILE=$BASE_SCRIPT_DIR/compose-files/$TARGET_ENV.yml

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

# Check for specific arguments
while [ "$END_OF_ARGUMENT_PARSING" != "true" ] ; do
    END_OF_ARGUMENT_PARSING=true
    if [ "$1" == "--build-no-cache" ] ; then
        BUILD_NO_CACHE="--no-cache"
        END_OF_ARGUMENT_PARSING=false
        shift
    fi
done

# Build R server image (Sanofi specific: need a Rserve image based on CentOS in order for Centrify - auth mechanism - to be installed and work correctly)
## Check if the target compose file needs the rserver part
if grep -e '^\s*image:\s*transmart_rserver' $COMPOSE_FILE ; then
    cd $BASE_SCRIPT_DIR/rserver
    ## First we need to check that the Oracle InstantClient rpms have been downloaded by the user
    ORACLE_INSTANTCLIENT_MAJOR_VERSION=12.1
    ORACLE_INSTANTCLIENT_VERSION=$ORACLE_INSTANTCLIENT_MAJOR_VERSION.0.2.0-1
    ORACLE_INSTANTCLIENT_DEVEL_RPM=oracle-instantclient$ORACLE_INSTANTCLIENT_MAJOR_VERSION-devel-$ORACLE_INSTANTCLIENT_VERSION.x86_64.rpm
    ORACLE_INSTANTCLIENT_BASIC_RPM=oracle-instantclient$ORACLE_INSTANTCLIENT_MAJOR_VERSION-basic-$ORACLE_INSTANTCLIENT_VERSION.x86_64.rpm
    if [ ! -f "$ORACLE_INSTANTCLIENT_DEVEL_RPM" ] || [ ! -f "$ORACLE_INSTANTCLIENT_BASIC_RPM" ] ; then
        echo "You must first download the Oracle Instant Client installation rpms from http://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html .
    Download the following files and place them on $BASE_SCRIPT_DIR/rserver folder:
    - $ORACLE_INSTANTCLIENT_DEVEL_RPM
    - $ORACLE_INSTANTCLIENT_BASIC_RPM" >&2
        exit 2
    fi
    PREVIOUS_TRANSMART_RSERVER_IMAGE_ID=$(docker images --quiet transmart_rserver || echo "")
    docker build --build-arg https_proxy=$https_proxy_IN_CONTAINER --build-arg http_proxy=$http_proxy_IN_CONTAINER \
        --build-arg ORACLE_INSTANTCLIENT_MAJOR_VERSION=$ORACLE_INSTANTCLIENT_MAJOR_VERSION \
        --build-arg ORACLE_INSTANTCLIENT_VERSION=$ORACLE_INSTANTCLIENT_VERSION \
        $BUILD_NO_CACHE -t transmart_rserver ./

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
fi

docker-compose -f $COMPOSE_FILE build $BUILD_NO_CACHE
docker-compose -f $COMPOSE_FILE down --volumes
docker-compose -f $COMPOSE_FILE up -d --force-recreate $*

# Compute passed time thanks to http://stackoverflow.com/q/16908084/535203
ENDTIME=$(date +%s)
echo "$0 executed in $(($ENDTIME - $STARTTIME)) seconds."