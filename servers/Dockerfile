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
ENV TMS_SCRIPTS_DIR $SCRIPTS_BASE/Scripts

# install make, curl, unzip, tar
RUN apt-get install -y make curl tar

# set up the transmart-data folder
RUN cd $INSTALL_BASE && wget https://github.com/anthony-o/transmart-data/archive/sanofi-release-16.1.tar.gz && tar xvzf sanofi-release-16.1.tar.gz && ln -nfs $INSTALL_BASE/transmart-data-sanofi-release-16.1 transmart-data
ENV TM_DATA_DIR $INSTALL_BASE/transmart-data

# set up the tranSMART-ETL folder
RUN cd $INSTALL_BASE/transmart-data/env && wget http://library.transmartfoundation.org/release/release16_1_0_artifacts/tranSMART-ETL-release-16.1.zip && unzip tranSMART-ETL-release-16.1.zip && ln -nfs $INSTALL_BASE/transmart-data/env/tranSMART-ETL-release-16.1 tranSMART-ETL
ENV TM_ETL_DIR $INSTALL_BASE/transmart-data/env/tranSMART-ETL

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
#RUN cd $INSTALL_BASE/transmart-data && make -C env ../vars && cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesVars.sh
RUN cp $TM_DATA_DIR/vars.sample $TM_DATA_DIR/vars && \
	sed -i "s|/path/to/transmart-ETL|$TM_ETL_DIR|g" $TM_DATA_DIR/vars && \
	sed -i "s|/path/to/data-integration|$TM_DATA_DIR/env/data-integration|g" $TM_DATA_DIR/vars && \
	sed -i "s/#ORACLE=1/ORACLE=1/" $TM_DATA_DIR/vars && \
	sed -i "s/^#export BIOMART_USER_PWD/export BIOMART_USER_PWD/" $TM_DATA_DIR/vars && \
	echo "export SOLR_OPTS=-Duser.timezone=Europe/Paris" >> $TM_DATA_DIR/vars && \
	cd $SCRIPTS_BASE/Scripts/install-ubuntu/checks && ./checkFilesVars.sh

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
RUN echo 'CATALINA_OPTS="-Duser.timezone=Europe/Paris -XX:MaxPermSize=1g -Xmx2g -Xms512m -Djava.awt.headless=true -XX:+UseConcMarkSweepGC $CATALINA_OPTS"' >> $CATALINA_HOME/bin/setenv.sh
# Ability to download / export files from "Browse"
RUN sed -i 's|HTTP/1.1"|HTTP/1.1" maxHttpHeaderSize="32000" URIEncoding="UTF-8"|g' $CATALINA_HOME/conf/server.xml
RUN sed -i 's|AJP/1.3"|AJP/1.3" packetSize="32000" URIEncoding="UTF-8" useBodyEncodingForURI="UTF-8"|g' $CATALINA_HOME/conf/server.xml

RUN cp -ar $CATALINA_HOME/webapps $CATALINA_HOME/webapps.orig

# Install cmd.sh dependencies & following part of this Dockerfile
RUN apt-get install -y netcat

# Install SOLR
RUN bash -c 'cd $INSTALL_BASE/transmart-data && source ./vars && make -C solr start & while ! nc -vz localhost 8983 2>/dev/null ; do sleep 2 ; done'
RUN cp -ar $TM_DATA_DIR/solr/solr $TM_DATA_DIR/solr/solr.orig
## Securing SolR access thanks to http://stackoverflow.com/a/39310582/535203
RUN sed -i '/<\/Configure>/i \
  <Call name="addBean">\
    <Arg>\
      <New class="org.eclipse.jetty.security.HashLoginService">\
        <Set name="name">SolR admin authentication</Set>\
        <Set name="config"><SystemProperty name="jetty.home" default="."/>/etc/auth/realm.properties</Set>\
        <Set name="refreshInterval">0</Set>\
      </New>\
    </Arg>\
  </Call>\
' $TM_DATA_DIR/solr/etc/jetty.xml
RUN sed -i '/<\/web-app>/i \
  <security-constraint>\
    <web-resource-collection>\
      <web-resource-name>SolR admin authentication</web-resource-name>\
      <url-pattern>/admin/</url-pattern>\
    </web-resource-collection>\
    <auth-constraint>\
      <role-name>solr-access</role-name>\
    </auth-constraint>\
  </security-constraint>\
  <login-config>\
    <auth-method>BASIC</auth-method>\
    <realm-name>SolR admin authentication</realm-name>\
  </login-config>\
' $TM_DATA_DIR/solr/etc/webdefault.xml

# Install ejstatd
RUN cd /opt && git clone https://github.com/anthony-o/ejstatd.git

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]