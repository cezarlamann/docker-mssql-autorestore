# Microsoft SQL Server With Automatic Restore of BAK and BACPAC Files | cezarlamann/mssql_ar
### docker-mssql-autorestore (mssql_ar)
Microsoft SQL Server Docker images with automatic restoration of .bak and .bacpac files for testing purposes

**https://hub.docker.com/r/cezarlamann/mssql_ar**

## How to use it

`docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=<MySaf3stPassw0rd>" -p 1433:1433 -v "/path/to/folder/with/backupfiles:/var/opt/mssql/backups" -v "<volume_here>:/var/opt/mssql/data" -d --name <container name> cezarlamann/mssql_ar:latest`

### Example: How do I run on Linux, personally?

``docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=MySaf3stPassw0rd#" -p 1433:1433 -v "`pwd`/dbs:/var/opt/mssql/backups" -v "sql1volume:/var/opt/mssql/data" -d --name sql1 cezarlamann/mssql_ar:latest``

To see what the container is doing when starting up, hit `docker logs -f <container_name>`, like `docker logs -f sql1` if you use the example above.

### More SQL Server Variables:
Refer to [this page](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15).

## Notes
- The `autorestorescript.sh` will detect if you already have the database you want to work with, so, if it is already restored, it will not restore it again. If you would like the database to be restored on each run, just remove the `-v "sql1volume:/var/opt/mssql/data"` part from the `run` command.
- If you'd like to restore new images apart from the ones you already have restored, just copy your new backup file into the folder you set up for backup files, stop the container with `docker stop <container name>` and start it again with `docker start <container name>`
- **The mssql service running in containers from this image is currently running as `root` by default and is provided AS-IS due to a volume mounting bug on Linux. It has been created with development and testing contexts in mind. I'm not responsible for anything that can happen if you use it in production scenarios. Be warned :)**

## Build instructions

- Run the `build.sh` script inside of the `mssql-autorestore` folder.