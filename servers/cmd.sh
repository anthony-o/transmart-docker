#!/bin/bash

set -x

WORKSPACE_DIR=/workspace
GIT_URL_BASE=https://github.com/anthony-o
BRANCH=sanofi-release-16.1

# The following line is used because we had "Error Error packaging application: Error occurred processing message bundles: Error starting Sun's native2ascii:  (Use --stacktrace to see the full trace)" when trying to build transmartApp with grails
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
# Init PATH
source $HOME/.sdkman/bin/sdkman-init.sh

# Set -e only now because $HOME/.sdkman/bin/sdkman-init.sh has some command which returns non 0 status
set -e

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
rm $WORKSPACE_DIR/current_footprint || echo "No current revisions counts"
for PROJECT in folder-management-plugin transmartApp transmart-dev transmart-rest-api SmartR; do
	if [ ! -d $WORKSPACE_DIR/$PROJECT ] ; then
		git clone $GIT_URL_BASE/$PROJECT.git $WORKSPACE_DIR/$PROJECT
	fi
	cd $WORKSPACE_DIR/$PROJECT
	UNTRACKED_FILES=$(git ls-files --others --exclude-standard)
	if [ -n "$UNTRACKED_FILES" ] ; then
		for UNTRACKED_FILE in $UNTRACKED_FILES ; do
			UNTRACKED_FILES="$UNTRACKED_FILES$(echo $UNTRACKED_FILE)$(cat $UNTRACKED_FILE)"
		done
	fi
	GIT_DIFF=$(git diff)$UNTRACKED_FILES
	if [ -n "$GIT_DIFF" ] ; then
		echo "$GIT_DIFF" >> $WORKSPACE_DIR/current_footprint
	else
		git fetch
		if [ -n "$(git checkout $BRANCH | grep '"git pull"' || echo "")" ] ; then
			git pull
		fi
		git rev-list --count HEAD >> $WORKSPACE_DIR/current_footprint
	fi
done

# Build if necessary (using rev-list count feature thanks to http://stackoverflow.com/a/38819020/535203)
cd $WORKSPACE_DIR/transmartApp
if [ ! -f $WORKSPACE_DIR/build_footprint ] || [ "$(cat $WORKSPACE_DIR/build_footprint)" != "$(cat $WORKSPACE_DIR/current_footprint)" ] ; then

	if [ -n "$GRAILS_CLEAN_ALL" ] ; then
		grails clean-all
	fi
	grails clean
	# Must launch 2 times because on the first time, the plugin transmart-core-db-tests will compile with errors
	grails war || grails war
fi
# Move to war-files dir
cp target/*.war $INSTALL_BASE/war-files/
cp $WORKSPACE_DIR/{current,build}_footprint

# Install war files
cp $INSTALL_BASE/war-files/*.war $CATALINA_HOME/webapps/

# Install LDAP cert if LDAPS is used somewhere in configuration
# grep -oP thanks to http://unix.stackexchange.com/a/13472/29674
LDAPS_URL=$(grep -oP '(?<=ldaps://)[\w\.-]+(:[0-9]*)?' $HOME/.grails/transmartConfig/Config.groovy)
if [ -n "$LDAPS_URL" ] ; then
	# We must download the cert & install it to the java cacerts
	# retrieving the cert thanks to http://stackoverflow.com/a/6742204/535203 which pointed to https://www.madboa.com/geek/openssl/#cert-retrieve
	echo | openssl s_client -connect $LDAPS_URL 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/cert.pem
	CACERTS_PATH=$JAVA_HOME/jre/lib/security/cacerts
	# Copy original cacerts or retrieve it
	if [ -f $CACERTS_PATH.orig ] ; then
		cp $CACERTS_PATH{.orig,}
	else
		cp $CACERTS_PATH{,.orig}
	fi
	# Import cert thanks to http://stackoverflow.com/a/6742204/535203
	keytool -import -file /tmp/cert.pem -alias ldaps_cert -keystore $CACERTS_PATH -storepass changeit -noprompt
	rm /tmp/cert.pem
fi

# Configure vars with current Oracle settings
sed -i "s/^ORAHOST=.*$/ORAHOST=$(grep -oP '(?<=jdbc:oracle:thin:@)[^:]*' ~/.grails/transmartConfig/DataSource.groovy)/" $TM_DATA_DIR/vars
sed -i "s/^ORAPORT=.*$/ORAPORT=$(grep -oP '(?<=jdbc:oracle:thin:@)[^"]*' ~/.grails/transmartConfig/DataSource.groovy | cut -d: -f 2)/" $TM_DATA_DIR/vars
sed -i "s/^ORASID=.*$/ORASID=$(grep -oP '(?<=jdbc:oracle:thin:@)[^"]*' ~/.grails/transmartConfig/DataSource.groovy | cut -d: -f 3)/" $TM_DATA_DIR/vars
sed -i "s/^ORAUSER=.*$/ORAUSER=$(grep -oP '(?<=username = ")[^"]*' ~/.grails/transmartConfig/DataSource.groovy)/" $TM_DATA_DIR/vars
ORAPASSWORD=$(grep -oP '(?<=password = ")[^"]*' ~/.grails/transmartConfig/DataSource.groovy)
sed -i "s/^ORAPASSWORD=.*$/ORAPASSWORD=$ORAPASSWORD/" $TM_DATA_DIR/vars
sed -i "s/BIOMART_USER_PWD=.*$/BIOMART_USER_PWD=$ORAPASSWORD/" $TM_DATA_DIR/vars

# Load, configure and start SOLR
if [ -z "$(ls $TM_DATA_DIR/solr/solr)" ] ; then
	# Retrieving original data due to Docker volume mount
	cp -ar $TM_DATA_DIR/solr/solr{.orig/*,/}
fi
find $TM_DATA_DIR/solr/solr -name 'data-config.xml' -exec rm {} \;

cd $INSTALL_BASE/transmart-data
source ./vars
make -C solr start > $INSTALL_BASE/transmart-data/solr.log 2>&1 &

# Wait for SOLR to start
while ! nc -vz localhost 8983 ; do
	sleep 2
done

# This last statement rebuilds all the indexes (should be done after each database load; and with SOLR running as above). You will also need to rebuild the index if you do any editing on the browse page in the tranSMART web application; browse page editing is not covered in these notes.
make -C solr browse_full_import rwg_full_import sample_full_import

# start Rserve
if [ -z "$USE_REMOTE_RSERVE" ] ; then
	# The following 2 lines ended with "Fatal error: you must specify '--save', '--no-save' or '--vanilla'"
	#cd $SCRIPTS_BASE/Scripts/install-ubuntu
	#./runRServe.sh
	cd $INSTALL_BASE/transmart-data
	source vars
	source /etc/profile.d/Rpath.sh
	R CMD Rserve --no-save
fi

# start Tomcat
if [ -n "$DEBUG_WITH_JPDA" ] ; then
	catalina.sh jpda run
else
	catalina.sh run
fi