#!/bin/bash

source ./functions.sh

MSSQL_DATA_ROOT="/var/opt/mssql"
MSSQL_DATA="$MSSQL_DATA_ROOT/data"
MSSQL_BKPS="$MSSQL_DATA_ROOT/backups"

mkdir -p "$MSSQL_BKPS"

cd $MSSQL_DATA_ROOT || exit

RETRIES=10
SLEEP_TIME=5

# check if the log exists and the
# script has "read" rights on it
execute_with_retry check_log_access $RETRIES $SLEEP_TIME

execute_with_retry check_sql_server_ready $RETRIES $SLEEP_TIME

restore_backups "localhost" "1433" "sa" "$MSSQL_SA_PASSWORD" "$MSSQL_BKPS" "$MSSQL_DATA"


