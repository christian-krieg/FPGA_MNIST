# For more information, please refer to https://aka.ms/vscode-docker-python
# This is a modified version based on the GHDL docker image
FROM ghdl/ext:latest

LABEL project="EggNetHdl"
LABEL author="Benjamin Kulnik"

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE 1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED 1

# Install pip requirements
ADD requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

# -------------------------------
# Setup Work Environment
# 
# Create a new folder and copy all files to the contaienr. This makes sure no local files will be modified.
# Though this is though if docker is used during development because if a file changes the `docker build` 
# command  needs to run again. For development it is therefore a better way to mount the source folder via 
# the `-v` flag and then switch to this folder
WORKDIR /vivado_src
ADD . /vivado_src   

# Switching to a non-root user, please refer to https://aka.ms/vscode-docker-python-user-rights
RUN useradd appuser && chown -R appuser /vivado_src
USER appuser

# Expose ports so the python debugger can attach
EXPOSE 5678/tcp
EXPOSE 5678/udp


# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
# We can directly run VUnit when the container is started (good for CI Servers)
# CMD ["python", "run.py"]
# or we select as the entrypoint simply a shell
ENTRYPOINT [ "/bin/bash" ]