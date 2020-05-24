# !!! Important !!!
# This docker file needs to be run from the toplevel project directory in orde
# to copy all files needed. Otherwise an "out of build context" error message
# will appear
#
# The command to properly buld this is then:
#
#   docker build -t eggnet/vhdl ./vivado/NN_IP/EggNet_1.0
#
# Fortunately this needs to be done only once. To use it, try the command
#   
#   docker run --rm -it -v ${pwd}:eggnet/src eggnet/vhdl

# For more information, please refer to https://aka.ms/vscode-docker-python
# This is a modified version based on the GHDL docker image
FROM ghdl/ext:latest

LABEL project="EggNet VUnit VHDL Testbench"
LABEL author="Benjamin Kulnik"

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE 1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED 1

# Copy the python libraries and weights to the container
# Install pip requirements
WORKDIR /eggnet
ADD ./vivado/NN_IP/EggNet_1.0/requirements.txt /eggnet
ADD ./python                                   /eggnet/libs/python
ADD ./net/final_weights                        /eggnet/constants/weights

# It is possible to copy all files to the container. In this case the original data
# wont be modified -> good for testing, bad for developing
# ADD vivado/NN_IP/EggNet_1.0/                 /eggnet/src
  

RUN python -m pip install --upgrade pip
RUN python -m pip install --no-cache-dir -r requirements.txt

# Install editors
RUN apt-get update && \ 
    apt-get install -y vim nano && \
    apt-get autoclean && apt-get autoremove

# Install SWIG dependencies 
RUN apt-get install -y --no-install-recommends build-essential libpcre3-dev wget

# Setup SWIG for python libraries
RUN mkdir /tmp/swig && \
    cd /tmp/swig && \
    wget http://prdownloads.sourceforge.net/swig/swig-4.0.1.tar.gz && \
    tar -xf swig-4.0.1.tar.gz && \
    cd swig-4.0.1 && \
    ./configure && \
    make && \
    make install && \
    rm -rf /tmp/swig


# Install python libraries
RUN cd /eggnet/libs/python && \  
    pip install --no-cache-dir -r requirements-min.txt && \
    python EggNetExtension/setup.py build_ext --build-lib ./EggNetExtension && \
    pip install --no-cache-dir ./EggNetExtension && \
    pip install --no-cache-dir  ./EggNet && \
    rm -rf EggNetExtension/dist && rm -rf EggNetExtension/build

# WORKDIR /vivado_src
# ADD . /vivado_src


# Switching to a non-root user, please refer to https://aka.ms/vscode-docker-python-user-rights
RUN useradd -m appuser && chown -R appuser /eggnet
USER appuser

# Expose ports so the python debugger can attach
EXPOSE 5678/tcp
EXPOSE 5678/udp


# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
# CMD ["python", "run.py"]
#
ENTRYPOINT [ "/bin/bash" ]