FROM tomcat:7.0.70-jre7

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y vim less unzip

# Installing tranSMART, inspired by https://github.com/tranSMART-Foundation/Scripts/blob/release-16.1/install-ubuntu/InstallTransmart.sh

ENV INSTALL_BASE /usr/local/transmart
ENV SCRIPTS_BASE /usr/local/transmart-scripts

RUN mkdir $INSTALL_BASE
RUN mkdir $SCRIPTS_BASE

# Installing Scripts
RUN cd $SCRIPTS_BASE && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/Scripts-release-16.1.zip && unzip Scripts-release-16.1.zip && ln -nfs $SCRIPTS_BASE/Scripts-release-16.1 Scripts
ENV TMS_SCRIPTS_DIR $SCRIPTS_BASE/Scripts-release-16.1

# install make, curl, unzip, tar
RUN apt-get install -y make curl tar

# set up the transmart-data folder
RUN cd $INSTALL_BASE && wget https://github.com/anthony-o/transmart-data/archive/sanofi-release-16.1.tar.gz && tar xvzf sanofi-release-16.1.tar.gz && ln -nfs $INSTALL_BASE/transmart-data-sanofi-release-16.1 transmart-data
ENV TM_DATA_DIR $INSTALL_BASE/transmart-data-sanofi-release-16.1

# set up the tranSMART-ETL folder
RUN cd $INSTALL_BASE/transmart-data/env && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/tranSMART-ETL-release-16.1.zip && unzip tranSMART-ETL-release-16.1.zip && ln -nfs $INSTALL_BASE/transmart-data/env/tranSMART-ETL-release-16.1 tranSMART-ETL
ENV TM_ETL_DIR $INSTALL_BASE/transmart-data/env/tranSMART-ETL-release-16.1

# Installing war files
RUN cd $INSTALL_BASE && mkdir war-files

## Installing gwava.war
RUN cd $INSTALL_BASE/war-files && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/gwava.war

# Install of basic tools and dependencies
RUN apt-get install -y git rsync libcairo-dev php5-cli php5-json curl tar openjdk-7-jdk gfortran g++ unzip libreadline-dev libxt-dev libpango1.0-dev libprotoc-dev texlive-fonts-recommended tex-gyre liblz4-tool pv zip && cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkMakefilePackages.sh

# Dependency: Install of tranSMART-ETL
RUN cd $INSTALL_BASE/transmart-data && make -C env update_etl && cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesETLFolder.sh

# Dependency: Install of data-integration
RUN cd $INSTALL_BASE/transmart-data && make -C env data-integration && cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesDataIntegrationFolder.sh

# Dependency: Install of vars
RUN cd $INSTALL_BASE/transmart-data && make -C env ../vars && cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesVars.sh

# Dependency: Install of grails, groovy
RUN apt-get install -y ant maven
RUN curl -s get.sdkman.io | bash
RUN bash -c 'source $HOME/.sdkman/bin/sdkman-init.sh && echo "Y" | sdk install grails 2.3.11'
RUN bash -c 'source $HOME/.sdkman/bin/sdkman-init.sh && echo "Y" | sdk install groovy 2.4.5'
RUN cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkSdkmanApps.sh

# Checks on install of tools and dependencies # Don't execute ./basics.sh nor ./checkVersions.sh because they need psql which is not installed here because we use an oracle DB
RUN cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesBasic.sh

# Updates on Tomcat
# Fixing "ORA-01882: timezone region not found" and "java.lang.OutOfMemoryError: Java heap space" & following the installation instructions on https://wiki.transmartfoundation.org/display/transmartwiki/Install+the+current+official+release#Installthecurrentofficialrelease-InstallGrails2.x
RUN echo "CATALINA_OPTS='-Duser.timezone=Europe/Paris -XX:MaxPermSize=1g -Xmx2g -Xms512m -Djava.awt.headless=true -XX:+UseConcMarkSweepGC'" >> $CATALINA_HOME/bin/setenv.sh

RUN cp -ar $CATALINA_HOME/webapps $CATALINA_HOME/webapps.orig

# Install R, Rserve and other packages
RUN bash -c 'cd $INSTALL_BASE/transmart-data && source ./vars && make -C R install_packages && echo "export PATH=$INSTALL_BASE/transmart-data/R/root/bin:\$PATH" > /etc/profile.d/Rpath.sh && source /etc/profile.d/Rpath.sh'
RUN bash -c 'cd $INSTALL_BASE/transmart-data && source ./vars && TRANSMART_USER=root make -C R install_rserve_init'
RUN cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesR.sh && ./checkR.sh

# Install cmd.sh dependencies & following part of this Dockerfile
RUN apt-get install -y netcat

# Install SOLR
RUN bash -c 'cd $INSTALL_BASE/transmart-data && source ./vars && make -C solr start & while ! nc -vz localhost 8983 2>/dev/null ; do sleep 2 ; done'

# Updates on Tomcat
# Ability to download / export files from "Browse"
RUN sed -i 's|HTTP/1.1"|HTTP/1.1" maxHttpHeaderSize="32000" URIEncoding="UTF-8"|g' $CATALINA_HOME/conf/server.xml
RUN sed -i 's|AJP/1.3"|AJP/1.3" packetSize="32000" URIEncoding="UTF-8" useBodyEncodingForURI="UTF-8"|g' $CATALINA_HOME/conf/server.xml

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]