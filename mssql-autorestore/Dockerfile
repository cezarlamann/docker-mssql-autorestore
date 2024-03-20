FROM mcr.microsoft.com/mssql/server:2022-latest

LABEL maintainer="Cezar Augustus Lamann"
LABEL version="2.0"
LABEL description=" \
    This image aims to provide an MS SQL Server testing environment \
    so it's easier for testers and devs to have a database backup \
    restored automatically and persisted during container cycles."

WORKDIR /var/opt/mssql

COPY autorestorescript.sh /var/opt/mssql/
COPY functions.sh /var/opt/mssql/
COPY entrypoint.sh /var/opt/mssql/

EXPOSE 1433

USER root
ENTRYPOINT /bin/bash ./entrypoint.sh