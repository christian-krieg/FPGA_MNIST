# Custom Dockerfile for ARM cross compile

# Download base image dockcross/linux-armv7a
# FROM dockcross/linux-armv7a
FROM arm32v7/ubuntu:trusty

LABEL AUTHOR="Benjamin Kulnik"
LABEL MAINTAINER="Benjamin Kulnik <benjamin.kulnik@student.tuwien.ac.at>"

ARG DEBIAN_FRONTEND="noninteractive"


# set the variables as per $(pyenv init -)
ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PATH="/opt/pyenv/shims:/opt/pyenv/bin:$PATH" \
    PYENV_ROOT="/opt/pyenv" \
    PYENV_SHELL="bash"


# Upgrade System
RUN apt-get update  && \
    apt-get upgrade -y 

# Install SWIG Dependencies
RUN apt-get install -y build-essential libpcre3-dev

# Install all PyEnv Dependencies
RUN apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    zlib1g-dev \
    libbz2-dev \
    libffi-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    # libssl1.0-dev \ 
    liblzma-dev \
    libssl-dev \
    llvm \
    make \
    netbase \
    pkg-config \
    tk-dev \
    wget \
    xz-utils \
    cmake \
    && apt-get autoremove && apt-get autoclean  \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add Files
ADD EggDriver/pysetup/requirements.txt      /EggDriver/pysetup/requirements.txt
ADD EggDriver/pysetup/python-versions.txt   /EggDriver/pysetup/python-versions.txt
ADD EggDriver/pysetup/info.py               /EggDriver/pysetup/info.py
RUN ls /EggDriver/pysetup

# The CC, CXX flags and so on must be removed to compile python
# RUN unset CC && unset CXX && unset CPP && unset LD && unset AR && unset AS
# ENV CC=gcc \
#     CPP=cpp \
#     CXX=g++ \
#     LD=ld \
#     AR=ar \
#     AS=as


# Create the pyenv versions
RUN git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT 
RUN for version in `cat /EggDriver/pysetup/python-versions.txt`; do echo $version; pyenv install $version; done 
RUN pyenv global `cat /EggDriver/pysetup/python-versions.txt` 
RUN pyenv rehash
RUN rm -rf /tmp/*

# && find $PYENV_ROOT/versions -type d '(' -name '__pycache__' -o -name 'test' -o -name 'tests' ')' -exec rm -rf '{}' + \
# && find $PYENV_ROOT/versions -type f '(' -name '*.pyo' -o -name '*.exe' ')' -exec rm -f '{}' + \
# && rm -rf /tmp/*

# Install pip manually, should not be needed
# RUN wget https://bootstrap.pypa.io/get-pip.py
# RUN python get-pip.py
# RUN rm /get-pip.py



# Install all requirements
RUN pip install --no-cache-dir -r /EggDriver/pysetup/requirements.txt \
    && find $PYENV_ROOT/versions -type d '(' -name '__pycache__' -o -name 'test' -o -name 'tests' ')' -exec rm -rf '{}' + \
    && find $PYENV_ROOT/versions -type f '(' -name '*.pyo' -o -name '*.exe' ')' -exec rm -f '{}' + \
    && rm -rf /tmp/*

# Install SWIG
RUN mkdir swig && \
    cd swig && \
    wget http://prdownloads.sourceforge.net/swig/swig-4.0.1.tar.gz && \
    tar -xf swig-4.0.1.tar.gz && \
    cd swig-4.0.1 && \
    ./configure && \
    make && \
    sudo make install && \
    make clean


# Install newest CMAKE
ENV cmversion=3.16
ENV cmbuild=8
RUN apt remove --purge --auto-remove cmake
RUN mkdir /cmake && cd /cmake
# Example

# wget https://cmake.org/files/v3.16/cmake-3.16.8-Linux-x86_64.tar.gz && mkdir /opt/cmake && cp /opt/cmake/ && tar -xf /cmake/*.tar.gz 
RUN wget https://cmake.org/files/v$cmversion/cmake-$cmversion.$cmbuild-Linux-x86_64.tar.gz && tar -xf *.tar.gz 
RUN mkdir /opt/cmake && cp /opt/cmake/
RUN ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake

# Test CMAKE
RUN cmake --version

# RESTORE ENVIRONMENT VARS
# ENV AS=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-as \
#     AR=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-ar \
#     CC=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-gcc \
#     CPP=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-cpp \
#     CXX=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-g++ \
#     LD=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-ld \
#     FC=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-gfortran