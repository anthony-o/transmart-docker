FROM centos:7

# Installing R server, inspired by https://github.com/tranSMART-Foundation/Scripts/blob/master/install-ubuntu/InstallTransmart.sh
## First we install all the needed packages
## libXt-devel to provide Intrinsic.h and fix "X11 headers/libs are not available" thanks to https://www.centos.org/forums/viewtopic.php?t=5933 , http://linuxsoft.cern.ch/cern/slc59/i386/yum/updates/repoview/x-software-development.group.html and http://unix.stackexchange.com/a/346561/29674
## libpng-devel & cairo-devel to activate PNG capability in R
RUN yum groupinstall -y "Development Tools" && yum install -y libX11-devel libXt-devel readline-devel libpng-devel cairo-devel

## Inspired by https://github.com/tranSMART-Foundation/transmart-data/blob/master/R/Makefile
ENV R_VERSION 3.2.1
ENV R_MIRROR http://cloud.r-project.org
ENV CRAN_MIRROR $R_MIRROR
ENV R_SOURCE R-$R_VERSION
ENV R_FLAGS "-O2 -march=native"
ENV R_PARENT_DIRECTORY /opt
#ENV R_PREFIX $R_PARENT_DIRECTORY/$R_SOURCE/root
RUN cd $R_PARENT_DIRECTORY && \
    curl -f $R_MIRROR/src/base/R-3/$R_SOURCE.tar.gz | tar xzf - && \
    cd $R_SOURCE && mkdir build && cd build && \
        CFLAGS="$R_FLAGS" \
        CXXFLAGS="$R_FLAGS" \
        FFLAGS="$R_FLAGS" \
        LIBnn=lib \
#        LDFLAGS="-Wl,-rpath=$R_PREFIX/lib/R/lib,--enable-new-dtags" \
        LDFLAGS="-Wl,-rpath=/usr/lib/R/lib,--enable-new-dtags" \
#    ../configure --prefix=$R_PREFIX \
    ../configure \
        --enable-R-shlib --with-readline \
        --enable-R-profiling --enable-memory-profiling \
        --with-libpng --without-jpeglib --without-libtiff \
        --without-system-xz --without-ICU \
        --without-recommended-packages && \
    cd .. && make -C build -j8 && make -C build -j8 install && \
    ln -nfs $R_PARENT_DIRECTORY/$R_SOURCE $R_PARENT_DIRECTORY/R

# Systemd integration for CentOS:7 Docker image, following https://github.com/docker-library/docs/tree/master/centos#systemd-integration
ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Install RStudio Server
## Inspired by https://www.rstudio.com/products/rstudio/download-server/#tab-6736bf3d67862e85b94
ENV RSTUDIO_VERSION 1.0.136
RUN yum install -y wget && cd /tmp && wget https://download2.rstudio.org/rstudio-server-rhel-$RSTUDIO_VERSION-x86_64.rpm && \
    yum install -y --nogpgcheck rstudio-server-rhel-$RSTUDIO_VERSION-x86_64.rpm && \
    rm rstudio-server-rhel-$RSTUDIO_VERSION-x86_64.rpm

ADD cran_pkg.R /tmp/
ADD other_pkg.R /tmp/
RUN yum install -y cairo-devel && \
    R -f /tmp/cran_pkg.R && \
    R -f /tmp/other_pkg.R && \
    rm -rf /tmp/*.R

    # Install additionnal R packages: RMarkdown
#RUN yum install -y cairo-devel
#RUN R CMD INSTALL formatR
#RUN R CMD INSTALL highr
#RUN R CMD INSTALL markdown
#RUN R CMD INSTALL yaml
#RUN R CMD INSTALL htmltools
#RUN R CMD INSTALL knitr
#RUN R CMD INSTALL rmarkdown
RUN R -e "install.packages(c('formatR', 'highr', 'markdown', 'yaml', 'htmltools', 'knitr', 'rmarkdown'), repos='$R_MIRROR');"
    # Install additionnal R packages: RInterface (thanks to http://stackoverflow.com/a/1250279/535203 for simple quote escaping)
RUN yum install -y openssl-devel libssh2-devel libcurl-devel protobuf-devel protobuf-c-compiler && R -e "install.packages('devtools', repos='$R_MIRROR'); require(devtools); install_github('transmart/RInterface');"

# Installing additionnal packages needed by RStudio and RMarkdown
## initscripts needed by rstudio-server script else I have a "/etc/init.d/rstudio-server: line 8: /etc/rc.d/init.d/functions: No such file or directory" (thanks to http://unix.stackexchange.com/a/347089/29674 )
## which needed by rstudio-server, else we have "ERROR r error 4 (R code execution error) [errormsg=Error in system(paste(which, shQuote(names[i])), intern = TRUE, ignore.stderr = TRUE)" (thanks to https://support.rstudio.com/hc/en-us/community/posts/200653226-Can-t-start-R-Studio-Fatal-error-R-code-execution-error )
## xorg-x11-fonts-Type1 needed for Cairo scripts to avoid "No font found in Rcairo_set_font"
RUN yum install -y xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-server-Xvfb xorg-x11-fonts-base xorg-x11-fonts-Type1 initscripts which && \
    # Installing additionnal packages needed by Centrify
    # yum install -y perl && \ # Already installed by previous packages
    # In order to prevent the creation of /var/run/nologin which makes /etc/pam.d/login to fail with "System is booting up. See pam_nologin(8)" (testing with "pamtester --verbose rstudio x003916a authenticate acct_mgmt" thanks to http://askubuntu.com/a/778700/29219 )
    rm /usr/lib/tmpfiles.d/systemd-nologin.conf && \
    # In order for Rserve to be accessible remotly, by transmart
    echo "remote enable" > /etc/Rserv.conf

ADD cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/cmd.sh

CMD ["/usr/local/bin/cmd.sh"]