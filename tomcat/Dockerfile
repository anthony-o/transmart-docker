FROM tomcat:7.0.70-jre7

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y vim less

# Fixing "ORA-01882: timezone region not found" and "java.lang.OutOfMemoryError: Java heap space" & following the installation instructions on https://wiki.transmartfoundation.org/display/transmartwiki/Install+the+current+official+release#Installthecurrentofficialrelease-InstallGrails2.x
RUN echo "CATALINA_OPTS='-Duser.timezone=Europe/Paris -XX:MaxPermSize=1g -Xmx2g -Xms512m -Djava.awt.headless=true -XX:+UseConcMarkSweepGC'" >> $CATALINA_HOME/bin/setenv.sh

RUN cp -ar $CATALINA_HOME/webapps $CATALINA_HOME/webapps.orig

ADD cmd.sh /usr/local/bin/cmd.sh
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]