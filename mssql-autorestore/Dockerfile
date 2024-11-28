ARG BASE_TAG=latest
FROM mcr.microsoft.com/mssql/server:${BASE_TAG}

LABEL maintainer="Cezar Augustus Lamann"
LABEL version="3.0"
LABEL description=" \
    This image aims to provide an MS SQL Server testing environment \
    so it's easier for testers and devs to have a database backup \
    restored automatically and persisted during container cycles."

WORKDIR /var/opt/mssql

COPY autorestorescript.sh /var/opt/mssql/
COPY util_functions.sh /var/opt/mssql/
COPY db_functions.sh /var/opt/mssql/
COPY entrypoint.sh /var/opt/mssql/

USER root

RUN apt-get update && apt-get install unzip -y

RUN wget -progress=bar:force -q -O sqlpackage.zip https://aka.ms/sqlpackage-linux && \
    unzip -qq sqlpackage.zip -d /opt/sqlpackage && \
    rm sqlpackage.zip && \
    chmod +x /opt/sqlpackage/sqlpackage && \
    ln -sf /opt/sqlpackage/sqlpackage /usr/bin/sqlpackage && \
    cd / && \
    ln -sf "$(find . -iname "sqlcmd" -exec realpath {} \; -quit)" /usr/bin/sqlcmd && \
    ln -sf "$(find . -iname "bcp" -exec realpath {} \; -quit)" /usr/bin/bcp && \
    cd /var/opt/mssql

EXPOSE 1433
ENTRYPOINT /bin/bash ./entrypoint.sh