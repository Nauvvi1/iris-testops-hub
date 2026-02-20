FROM intersystemsdc/iris-community:latest

USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Project files inside container
WORKDIR /opt/testops
COPY src/ /opt/testops/src/
COPY iris.script /opt/testops/iris.script
COPY init-testops.sh /docker-entrypoint-initdb.d/10-init-testops.sh

RUN chmod +x /docker-entrypoint-initdb.d/10-init-testops.sh && \
    mkdir -p /opt/testops/attachments && \
    chown -R irisowner:irisowner /opt/testops /docker-entrypoint-initdb.d/10-init-testops.sh

USER irisowner

EXPOSE 52773 1972
