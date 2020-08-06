FROM mcr.microsoft.com/mssql/server:2019-CU6-ubuntu-18.04

MAINTAINER Cezar Augustus Lamann

ENV WORKSPACE_DB_NAME
WORKDIR /var/opt/mssql

COPY autorestorescript.sh /var/opt/mssql/
COPY entrypoint.sh /var/opt/mssql/

RUN chmod a+x /var/opt/mssql/autorestorescript.sh && \
    chmod a+x /var/opt/mssql/autorestorescript.sh

EXPOSE 1433

USER mssql
ENTRYPOINT /bin/bash ./entrypoint.sh