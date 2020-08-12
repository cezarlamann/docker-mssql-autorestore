FROM mcr.microsoft.com/mssql/server:2019-CU6-ubuntu-18.04

LABEL maintainer="Cezar Augustus Lamann"
LABEL version="1.0_2019_cu6_18.04"
LABEL description=" \
    This image aims to provide an MS SQL Server testing environment \
    so it's easier for testers and devs to have a database backup \
    restored automatically and persisted during container cycles."

ARG build_time_db_name="mydb"
ENV WORKSPACE_DB_NAME=$build_time_db_name

WORKDIR /var/opt/mssql

COPY autorestorescript.sh /var/opt/mssql/
COPY entrypoint.sh /var/opt/mssql/

EXPOSE 1433

USER root
ENTRYPOINT /bin/bash ./entrypoint.sh