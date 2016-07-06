#!/bin/bash

set -x
set -e

WORKSPACE_DIR=/workspace
GIT_URL_BASE=https://github.com/anthony-o
BRANCH=sanofi-release-16.1
CATALINA_HOME=/usr/local/tomcat

# Handling Proxy
rm ~/.m2/settings.in.xml || echo "settings.in.xml didn't exist."

for PROTO in HTTPS HTTP ; do
	PROXY_IN_CONTAINER_VAR=${PROTO}_PROXY
	# dynamic variable name thanks to http://stackoverflow.com/a/18124325/535203
	PROXY_IN_CONTAINER=${!PROXY_IN_CONTAINER_VAR}
	# Testing priority in bash thanks to http://wiki.bash-hackers.org/commands/classictest
	if [ -n "$PROXY_IN_CONTAINER" ] ; then
		PROXY_IN_CONTAINER_HOST=`echo $PROXY_IN_CONTAINER | sed -e's,^.*://\(.*\):.*,\1,g'`
		PROXY_IN_CONTAINER_PORT=`echo $PROXY_IN_CONTAINER | sed -e's,^.*://.*:\(.*\),\1,g'`
		if [ ! -f ~/.m2/settings.xml ] || ! grep "$PROXY_IN_CONTAINER_HOST" ~/.m2/settings.xml ; then
			# parsing url thanks to http://stackoverflow.com/a/6174447/535203
			cat >>~/.m2/settings.in.xml <<EOF
		<proxy>
			<id>$PROXY_IN_CONTAINER_VAR</id>
			<active>true</active>
			<protocol>`echo $PROXY_IN_CONTAINER | sed -e's,^\(.*\)://.*,\1,g'`</protocol>
			<host>$PROXY_IN_CONTAINER_HOST</host>
			<port>$PROXY_IN_CONTAINER_PORT</port>
			<nonProxyHosts>$PROXY_IN_CONTAINER_HOST</nonProxyHosts>
		</proxy>
EOF
		fi
		if [ ! -f ~/.grails/ProxySettings.groovy ] || ! grep "$PROXY_IN_CONTAINER_HOST" ~/.grails/ProxySettings.groovy ; then
			if [ -z "$GRAILS_PROXY_REMOVED" ] ; then
				rm ~/.grails/ProxySettings.groovy || echo "ProxySettings.groovy didn't exist."
				GRAILS_PROXY_REMOVED=true
			fi
			grails add-proxy $PROXY_IN_CONTAINER_VAR --host=$PROXY_IN_CONTAINER_HOST --port=$PROXY_IN_CONTAINER_PORT --offline
			grails set-proxy $PROXY_IN_CONTAINER_VAR --offline
		fi
	fi
done

if [ -f ~/.m2/settings.in.xml ] ; then
	cat >~/.m2/settings.xml <<EOF
<settings>
	<proxies>
`cat ~/.m2/settings.in.xml`
	</proxies>
</settings>
EOF
	rm ~/.m2/settings.in.xml
fi

export GRAILS_OPTS="-XX:MaxPermSize=1g -Xmx2g"

# Checkout project & branch
for PROJECT in folder-management-plugin transmartApp transmart-dev ; do
    if [ ! -d $WORKSPACE_DIR/$PROJECT ] ; then
        git clone $GIT_URL_BASE/$PROJECT.git $WORKSPACE_DIR/$PROJECT
    fi
    cd $WORKSPACE_DIR/$PROJECT
    git fetch
    git checkout $BRANCH
done

# Build
cd $WORKSPACE_DIR/transmartApp
if [ -n "$GRAILS_CLEAN_ALL" ] ; then
    grails clean-all
fi
# Must launch 2 times because on the first time, the plugin transmart-core-db-tests will compile with errors
grails war || grails war

# Move to tomcat
cp target/*.war $CATALINA_HOME/webapps/