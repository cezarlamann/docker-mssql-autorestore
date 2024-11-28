#!/bin/bash

exec_sql() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local statement="$5"
    shift 5  # Shift the positional parameters to exclude the first 5

    if [ -z "$password" ]; then
        echo "Error: Database password not provided." >&2
        return 1
    fi

    if [ -z "$statement" ]; then
        echo "Error: SQL script not provided." >&2
        return 1
    fi

    # Additional input validation (optional)
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a valid integer." >&2
        return 1
    fi

    # Execute sqlcmd command to run the SQL statement passing
    # flags to the command execution and capture the output
    local output

    output="$(sqlcmd -S "tcp:$host,$port" \
        -U "$user" -P "$password" \
        -d master \
        -Q "set nocount on;$statement;set nocount off" \
        -No \
        "$@")"

    # Return the output
    echo "$output"
}

get_list_of_current_dbs() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local statement="select name from sys.databases"

    local output
    output=$(exec_sql "$host" "$port" "$user" "$password" "$statement" -h-1)

    echo "$output"
}

check_dbs_in_bakfile() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local backup_file="$5"

    if [ -z "$backup_file" ]; then
        echo "Error: SQL backup file not provided." >&2
        return 1
    fi

    local statement="exec ('
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
    exec (''RESTORE FILELISTONLY FROM DISK = ''''$backup_file'''''');
    select top(2) [LogicalName], [PhysicalName], [Type] from @tv as Databases;
    ')"

    local output
    output=$(exec_sql "$host" "$port" "$user" "$password" "$statement" -y 0 -s ',')

    echo "$output"
}

restore_bak() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local filepath="$5"

    local exec_return dbs_in_bak db_name db_file db_log_name db_log_file restore_stmt

    dbs_in_bak=$(check_dbs_in_bakfile "$host" "$port" "$user" "$password" "$filepath")

    db_name=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -1)

    db_file=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -1)

    db_log_name=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -2 | tail -1)

    db_log_file=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -2 | tail -1)

    restore_stmt="RESTORE DATABASE [$filename_no_ext] FROM DISK=N'$filepath' WITH FILE=1, MOVE N'$db_name' TO N'$destination/$db_file', MOVE N'$db_log_name' TO N'$destination/$db_log_file'"

    console_log "DB Name (from file): \"$db_name\""
    console_log "DB File (from file): \"$db_file\""
    console_log "DB Log file name (from file): \"$db_log_name\""
    console_log "DB Log file (from file): \"$db_log_file\""
    console_log "Restore statement: \"$restore_stmt\""

    exec_return=$(exec_sql "$host" "$port" "$user" "$password" "$restore_stmt")

    echo "$exec_return"
}

import_bacpac() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local filepath="$5"

    local exec_return filename filename_no_ext restore_stmt

    filename=$(basename "$filepath")

    filename_no_ext="${filename%.*}"

    exec_return=$(sqlpackage /tu:"$user" /tp:"$password" /tsn:"$host" /a:"Import" /sf:"$filepath" /tdn:"$filename_no_ext" /tec:"False" | tee >(cat >&1))

    echo "$exec_return"
}

restore_backups() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local bkp_folder="$5"

    local filename full_path filename_no_ext current_dbs

    for file in "$bkp_folder"/*; do
        # Check if the file is not a regular file or does not match .bak or .bacpac
        if [ ! -f "$file" ] || { [[ "$file" != *.bak && "$file" != *.bacpac ]]; }; then
            continue
        fi

        filename=$(basename "$file")
        full_path=$(realpath "$file")
        filename_no_ext="${filename%.*}"

        console_log "Processing backup file: \"$filename_no_ext\""

        current_dbs=$(get_list_of_current_dbs "$host" "$port" "$user" "$password")

        if [ "$(grep -c "$filename_no_ext" <<<"$current_dbs")" -gt 0 ]; then
            console_log "The database \"$filename_no_ext\" is already present on the current server. Skipping it..."
            continue
        fi

        if [[ "$file" == *.bak ]]; then
            restore_bak "$host" "$port" "$user" "$password" "$full_path"
        elif [[ "$file" == *.bacpac ]]; then
            import_bacpac "$host" "$port" "$user" "$password" "$full_path"
        fi

    done
}
