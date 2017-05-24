FROM httpd:2.4.25-alpine

EXPOSE 443

RUN sed -i "s/#LoadModule proxy_module/LoadModule proxy_module/" conf/httpd.conf && \
    sed -i "s/#LoadModule proxy_http_module/LoadModule proxy_http_module/" conf/httpd.conf && \
    echo "Include conf/extra/transmart.conf" >> conf/httpd.conf && \
    sed -i "s|conf/server|conf/certs/server|g" conf/extra/httpd-ssl.conf && \
    cp -ar conf conf.original

ADD transmart.conf conf/extra/

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]