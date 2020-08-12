# docker-mssql-autorestore (mssql_ar)
Microsoft SQL Server Docker images with automatic restoration of .bak files for testing purposes

## How to use it
`docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=<MySaf3stPassw0rd>" -e "WORKSPACE_DB_NAME=any_db_name" -p 1433:1433 -v "/path/to/folder/with/bakfiles:/var/opt/mssql/backups" -v "<volume_here>:/var/opt/mssql/data" -d --name sql1 mssql_ar:<tag_here>`
  
### Example: How do I run on Linux, personally?
  
``docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=MySaf3stPassw0rd#" -e "WORKSPACE_DB_NAME=any_db_name" -p 1433:1433 -v "`pwd`/dbs:/var/opt/mssql/backups" -v "sql1volume:/var/opt/mssql/data" -d --name sql1 mssql_ar:latest``

## Notes
- `any_db_name`: is the name that will be given to the restored database, e.g.: If you have a database bak file where the `.mdf` file was named `foo` and you set the `WORKSPACE_DB_NAME` variable to `bar`, when you connect to the container, your restored database will be named `bar`;
- If you omit the `WORKSPACE_DB_NAME` variable, your database will be named as `mydb`;
- **The mssql service running in containers from this image is currently running as `root` by default and is provided AS-IS due to a volume mounting bug on Linux. It has been created with development and testing contexts in mind. I'm not responsible for anything that can happen if you use it in production scenarios. Be warned :)**
