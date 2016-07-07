FROM maven:3.3.9-jdk-7

RUN apt-get update && apt-get -y upgrade

RUN mkdir /usr/local/transmart

RUN cd /usr/local/transmart && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/Scripts-release-16.1.zip && unzip Scripts-release-16.1.zip
ENV TM_SCRIPTS_DIR /usr/local/transmart/Scripts-release-16.1

RUN cd /usr/local/transmart && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/transmart-data-release-16.1.zip && unzip transmart-data-release-16.1.zip
ENV TM_DATA_DIR /usr/local/transmart/transmart-data-release-16.1

RUN apt-get install -y make php5-cli php5-json

RUN cd $DATA_DIR && make -C env groovy && ln -nfs $DATA_DIR/env/groovy-2*/bin/groovy /usr/local/bin/
# Fixing "ORA-01882: timezone region not found" with user.timezone thanks for http://stackoverflow.com/questions/9156379/ora-01882-timezone-region-not-found#comment11515331_9156379 (can't use GROOVY_OPTS as Groovy 1.2.9 don't use this variable, by looking into its launch code)
# Fixing "java.net.SocketException: Connection reset" with java.security.egd thanks to http://stackoverflow.com/a/21542991/535203
ENV JAVA_OPTS="-Xmx2g -Duser.timezone=Europe/Paris -Djava.security.egd=file:/dev/./urandom"

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]