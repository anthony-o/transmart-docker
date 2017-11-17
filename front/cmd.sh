#!/bin/bash
set -x

if [ -f "$HTTPD_PREFIX/conf/certs/server.crt" ]; then
    # Restore configs
    for F in httpd.conf extra/httpd-ssl.conf; do
        cp -ar $HTTPD_PREFIX/conf.original/$F $HTTPD_PREFIX/conf/$F
    done
    # Patch the config to enable HTTPS
    sed -i "s/#LoadModule ssl_module/LoadModule ssl_module/" conf/httpd.conf
    sed -i "s/#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/" conf/httpd.conf
    if [ -f "$HTTPD_PREFIX/conf/certs/server-ca.crt" ]; then
        sed -i "s/#SSLCertificateChainFile/SSLCertificateChainFile/" conf/extra/httpd-ssl.conf
    fi
    ## Append http-ssl configuration at the end of the file in order to be loaded after transmart.conf, so that "LimitRequestFieldSize" that is defined there can be applied to the SSL virtualhost defined in SSL conf (thanks to https://stackoverflow.com/questions/24273399/how-to-change-the-limitrequestfieldsize-in-apache-2-4-2#comment72751119_25462375 )
    echo "Include conf/extra/httpd-ssl.conf" >> conf/httpd.conf
fi

## Create auth file for SolR if it doesn't exist
if [ ! -f "$HTTPD_PREFIX/conf/solr-auth/htpasswd" ] ; then
    # Generate a 12 length password thanks to https://gist.github.com/earthgecko/3089509 and https://unix.stackexchange.com/a/230676/29674
    SOLR_ADMIN_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    echo "$SOLR_ADMIN_PASSWORD" > $HTTPD_PREFIX/conf/solr-auth/clear_password
    htpasswd -bc "$HTTPD_PREFIX/conf/solr-auth/htpasswd" admin "$SOLR_ADMIN_PASSWORD"
fi

httpd-foreground