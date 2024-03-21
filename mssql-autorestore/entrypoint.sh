#!/bin/bash

/opt/mssql/bin/sqlservr & bash /var/opt/mssql/autorestorescript.sh && tail -f /dev/null