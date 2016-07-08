#!/bin/bash

set -x
set -e

cd "$TM_DATA_DIR"

if [ ! -f /workspace/vars ] ; then
    cp ./vars.sample /workspace/vars
    echo "Modify 'vars' file according to what you want and restart this script."
    exit 1
fi

. /workspace/vars

# Setting proxy for groovy & grapes download
for PROXY_VAR in http_proxy HTTP_PROXY ; do
    # dynamic variable name thanks to http://stackoverflow.com/a/18124325/535203
    if [ -n "${!PROXY_VAR}" ] ; then
        # parsing url thanks to http://stackoverflow.com/a/6174447/535203
        PROXY_HOST=`echo ${!PROXY_VAR} | sed -e's,^.*://\(.*\):.*,\1,g'`
        PROXY_PORT=`echo ${!PROXY_VAR} | sed -e's,^.*://.*:\(.*\),\1,g'`
        JAVA_PROXY="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT "
    fi
done
export JAVA_OPTS="$JAVA_PROXY$JAVA_OPTS"

function create_oracle_ddl {
	make oracle_drop || echo "Ignoring problem while dropping"
	make -C ddl/oracle drop_tablespaces || echo "Ignoring problem while dropping"
	make -j4 oracle
}

# Trying 2 times because the first time we have "General error during conversion: Error grabbing Grapes -- [unresolved dependency: net.sf.opencsv#opencsv;2.3: not found]"
create_oracle_ddl || create_oracle_ddl