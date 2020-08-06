#!/usr/bin/env bash

# "backups on folder" variable
BKPS_NA_PASTA=0

# testa se existe a pasta de backups
# check if the "backups" folder exists
# if not, it creates.
if [ ! -d /var/opt/mssql/backups ]; then
  mkdir -p /var/opt/mssql/backups
fi

# testa se existe a pasta de scripts
# check if the "scripts"
# if not, it creates.
if [ ! -d /var/opt/mssql/scripts ]; then
  mkdir -p /var/opt/mssql/scripts
fi

# "db not ready" message, so we can
# check if the mssql server/service
# is ready to go
DBREADY='db not ready'

# attempts
TENTATIVAS=0

MSSQL_DATA="/var/opt/mssql/data"

# check if the log exists and the
# script has "read" rights on it
ACESSO_LOG=$([ -r /var/opt/mssql/log/errorlog ]; echo $?)

# checa se o script tem acesso ao arquivo de log do mssql
# "do-while" to wait and check if the script has
# access to the logs, so we can check if the server
# is ready or not.
while [ $ACESSO_LOG -ne 0 ] && [ $TENTATIVAS -lt 10 ]
do
  ACESSO_LOG=$([ -r /var/opt/mssql/log/errorlog ]; echo $?)
  echo 'SQL Server Log Not Accessible yet... Waiting 2 seconds. Attempt '$((TENTATIVAS+1))
  sleep 2
  TENTATIVAS=$((TENTATIVAS+1))
done

# if it doesn't manage to check, bail with an error
if [ $TENTATIVAS -eq 10 ] && [ $ACESSO_LOG -ne 0 ]; then
  echo 'Script nao conseguiu acesso ao log do MSSQL em 10 tentativas. Abortando.'
  exit 1
else
  echo 'Log MSSQL acessivel. Continuando...'
fi

TENTATIVAS=0
DBREADY=0
# checa se o servico do sql server esta pronto
# check if the mssql service is ready...
while [ $DBREADY -lt 1 ] && [ $TENTATIVAS -lt 10 ]
do
  echo 'Checking SQL Server readiness... Attempt '$((TENTATIVAS+1))
  DBREADY=$(tail -30 /var/opt/mssql/log/errorlog | grep 'SQL Server is now ready' | wc -l)

  sleep 2
  TENTATIVAS=$((TENTATIVAS+1))
done

# if it doesn't manage to check in 10 attempts, bail with an error.
if [ $TENTATIVAS -eq 10 ] && [ $DBREADY -lt 1 ]; then
  echo 'MSSQL nao subiu em 10 tentativas. Abortando.'
  exit 1
else
  echo 'Servico MSSQL pronto. Continuando...'
fi

cd /var/opt/mssql

# lista somente os arquivos da pasta
# filtra os .bak
# get the "*.bak" files from volume folder...
BKPS_NA_PASTA=$(ls -1Lpq $PWD/backups/* | grep .bak)

if [ $(wc -l <<< $BKPS_NA_PASTA) -gt 0 ]; then
  # we got some.
  echo 'Backups disponiveis'

  # if the user doesn't give a db name, assume it is "mydb" and go.
  if [ -z "$WORKSPACE_DB_NAME" ]
  then
    echo "\$WORKSPACE_DB_NAME is empty. using 'mydb' as name."
    WORKSPACE_DB_NAME="mydb"
  fi

  # pega o primeiro bkp na pasta
  # grab the first .bak file from folder.
  BAK=$(head -1 <<< $BKPS_NA_PASTA)

  # Pega lista de DBS do banco de dados.
  # O parametro -h-1 remove os headers da consulta.
  # "set nocount off" remove msg "X lines affected"

  # get list of current dbs on server
  DBS_ATUAIS=$(/opt/mssql-tools/bin/sqlcmd -S tcp:localhost,1433 \
    -U sa -P $SA_PASSWORD \
    -d master \
    -Q 'set nocount on;select name from sys.databases;set nocount off' \
    -h-1)

  # Query de retornar os bancos de dados de um arquivo BAK.
  # Precisa ser alocada em uma table variable,
  # pois eh o resultado de um exec sobre arquivo.

  # get dbs from bak file. we need to assign the result
  # to a table variable so we can select data from it.
  STMT="exec ('
    set nocount on;
    DECLARE @tv TABLE (
      [LogicalName] varchar(128)
      , [PhysicalName] varchar(128)
      , [Type] varchar
      , [FileGroupName] varchar(128)
      , [Size] varchar(128)
      , [MaxSize] varchar(128)
      , [FileId]varchar(128)
      , [CreateLSN]varchar(128)
      , [DropLSN]varchar(128)
      , [UniqueId]varchar(128)
      , [ReadOnlyLSN]varchar(128)
      , [ReadWriteLSN]varchar(128)
      , [BackupSizeInBytes]varchar(128)
      , [SourceBlockSize]varchar(128)
      , [FileGroupId]varchar(128)
      , [LogGroupGUID]varchar(128)
      , [DifferentialBaseLSN]varchar(128)
      , [DifferentialBaseGUID]varchar(128)
      , [IsReadOnly]varchar(128)
      , [IsPresent]varchar(128)
      , [TDEThumbprint]varchar(128)
      , [SnapshotUrl]varchar(128)
    );
    insert into @tv
    exec (''RESTORE FILELISTONLY FROM DISK = ''''$BAK'''''');
    select top(2) [LogicalName], [PhysicalName], [Type] from @tv as Databases;
    ')"

  # retorna o resultado da consulta acima, retirando headers
  # e formatando como csv (separado por virgulas)

  # return a "csv-like" result from that query.
  BKP_NO_BAK=$(/opt/mssql-tools/bin/sqlcmd -S tcp:localhost,1433 -U sa -P $SA_PASSWORD -d master -Q "$STMT" -y 0 -s ',')

  # pega a primeira linha (head -1) da primeira coluna ($1)
  # grab the first line from first row
  DBNAME=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<< $BKP_NO_BAK | head -1)
  # pega a primeira linha (head -1) da segunda coluna ($2)
  # grab the first line from second row
  DBFILE=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<< $BKP_NO_BAK | head -1)

  # pega a segunda linha (head -2 | tail -1) da primeira coluna ($1)
  # grab the second line from first row
  DBLOGNAME=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<< $BKP_NO_BAK | head -2 | tail -1)

  # pega a segunda linha (head -2 | tail -1) da segunda coluna ($2)
  # grab the second line from second row
  DBLOGFILE=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<< $BKP_NO_BAK | head -2 | tail -1)

  # sql de restore
  # "restore database statement"
  RESTORE="
    RESTORE DATABASE [$WORKSPACE_DB_NAME] FROM DISK='$BAK'
      WITH MOVE '$DBNAME' TO '$MSSQL_DATA/$DBFILE'
         , MOVE '$DBLOGNAME' TO '$MSSQL_DATA/$DBLOGFILE'"

  # executa o comando de restore, retornando logs
  # para a pasta montada em volume do docker

  # execute the restore stmt and redirect the resulting log to the
  # mounted volume so you can check whatever happened.
  /opt/mssql-tools/bin/sqlcmd -S tcp:localhost,1433 -U sa -P $SA_PASSWORD -d master -Q "$RESTORE" -o /var/opt/mssql/backups/dbrestore.log
else
  # No "*.bak" files found. go.
  echo 'Sem backups disponiveis'
fi