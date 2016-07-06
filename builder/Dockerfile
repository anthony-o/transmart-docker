FROM maven:3.3.9-jdk-7

ENV GRAILS_VERSION 2.3.11
ENV GRAILS_HOME /usr/local/lib/grails

RUN wget https://github.com/grails/grails-core/releases/download/v$GRAILS_VERSION/grails-$GRAILS_VERSION.zip \
	&& unzip grails-$GRAILS_VERSION.zip

RUN mv grails-$GRAILS_VERSION /usr/local/lib/ \
	&& ln -nfs /usr/local/lib/grails-$GRAILS_VERSION $GRAILS_HOME \
	&& ln -nfs $GRAILS_HOME/bin/grails /usr/local/bin/ \
	&& ln -nfs $GRAILS_HOME/bin/grails-debug /usr/local/bin/ \
	&& ln -nfs $GRAILS_HOME/bin/startGrails /usr/local/bin/

ENV GRAILS_OPTS "-XX:MaxPermSize=1g -Xmx2g"

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]