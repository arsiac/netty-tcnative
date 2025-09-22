FROM --platform=linux/amd64 centos:7.6.1810

ENV SOURCE_DIR /root/source
ENV CMAKE_VERSION_BASE 3.26
ENV CMAKE_VERSION $CMAKE_VERSION_BASE.4
ENV NINJA_VERSION 1.7.2
ENV GO_VERSION 1.9.3
ENV MAVEN_VERSION 3.9.1

# Update to use the vault
RUN sed -i -e 's/^mirrorlist/#mirrorlist/g' \
    -e 's/^#baseurl=http:\/\/mirror.centos.org\/centos\/$releasever\//baseurl=https:\/\/linuxsoft.cern.ch\/centos-vault\/\/7.6.1810\//g' \
    /etc/yum.repos.d/CentOS-Base.repo

# install dependencies
RUN yum install -y \
 apr-devel \
 autoconf \
 automake \
 bzip2 \
 git \
 glibc-devel \
 gnupg \
 libapr1-dev \
 libtool \
 lsb-core \
 make \
 openssl-devel \
 patch \
 perl \
 perl-parent \
 perl-devel \
 tar \
 unzip \
 wget \
 which \
 zip \
 ninja-build \
 gcc-c++

RUN mkdir $SOURCE_DIR
WORKDIR $SOURCE_DIR

# Install Java
RUN yum install -y java-1.8.0-openjdk-devel golang
ENV JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk/"

# Install cmake
RUN curl -s https://cmake.org/files/v$CMAKE_VERSION_BASE/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz \
    --output cmake-$CMAKE_VERSION-linux-x86_64.tar.gz \
    && tar zvxf cmake-$CMAKE_VERSION-linux-x86_64.tar.gz \
    && mv cmake-$CMAKE_VERSION-linux-x86_64 /opt/ \
    && echo 'PATH=/opt/cmake-$CMAKE_VERSION-linux-x86_64/bin:$PATH' >> ~/.bashrc

RUN yum -y install centos-release-scl-rh
# Update repository urls as we need to use the vault now.
RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
RUN sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo

RUN yum -y install devtoolset-9-gcc devtoolset-9-gcc-c++
RUN echo 'source /opt/rh/devtoolset-9/enable' >> ~/.bashrc

# Native compile OpenSSL for current host - shared
RUN set -x && \
  source /opt/rh/devtoolset-9/enable && \
  wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
  tar xf openssl-${OPENSSL_VERSION}.tar.gz && \
  pushed openssl-${OPENSSL_VERSION} && \
  ./Configure linux-x86_64 --prefix=/opt/openssl-${OPENSSL_VERSION}-share shared && \
  make -j$(nproc) && make install && \
  popd

RUN rm -rf $SOURCE_DIR

# Downloading and installing SDKMAN!
RUN curl -s "https://get.sdkman.io" | bash

# Don't check the certificates as our curl version is too old.
RUN echo 'sdkman_insecure_ssl=true' >> $HOME/.sdkman/etc/config

# Installing Java and Maven, removing some unnecessary SDKMAN files
RUN bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
    yes | sdk install maven $MAVEN_VERSION && \
    rm -rf $HOME/.sdkman/archives/* && \
    rm -rf $HOME/.sdkman/tmp/*"

# Prepare our own build
ENV PATH /root/.sdkman/candidates/maven/current:$PATH

# This is workaround to be able to compile boringssl with atomics as while we use a recent gcc installation it still needs some
# help to define static_assert(...) as otherwise the compilation will fail due the system installed assert.h which missed this definition.
RUN mkdir ~/.include
RUN echo '#include "/usr/include/assert.h"' >>  ~/.include/assert.h
RUN echo '#define static_assert _Static_assert'  >>  ~/.include/assert.h
RUN echo 'export C_INCLUDE_PATH="$HOME/.include/"' >>  ~/.bashrc

# Cleanup
RUN yum clean all && \
    rm -rf /var/cache/yum
