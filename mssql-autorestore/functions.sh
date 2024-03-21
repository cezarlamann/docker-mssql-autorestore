#!/bin/bash

console_log() {
  local prefix="[ MSSQL AUTO-RESTORE SCRIPT ]: " # Prefix string provided as the first argument
  local str="$1"                                 # String to be prefixed provided as the second argument

  echo "${prefix}${str}" # Echo the prefixed string to the standard output
}

is_file_readable() {
    local file="$1"
    local is_readable=1  # Default to not readable
    
    # Check if the file is readable
    [ -r "$file" ]
    
    # Store the exit status of the previous command in is_readable variable
    is_readable=$?
    
    # Return the exit status
    return "$is_readable"
}

check_log_access() {
    is_file_readable /var/opt/mssql/log/errorlog
    return $?
}

check_sql_server_ready() {
    local file="/var/opt/mssql/log/errorlog"  # File to check
    
    # Check if the file exists
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist." >&2
        return 1
    fi

    # Use grep -q to check if the pattern exists in the file
    if grep -q 'SQL Server is now ready' "$file"; then
        return 0  # Pattern found, return success
    else
        return 1  # Pattern not found, return failure
    fi
}

execute_with_retry() {
    local func="$1"       # Function to execute
    local retries=10      # Number of retries
    local sleep_time=5    # Time to sleep between retries

    if [ -z "$func" ]; then
        echo "Error: Function name not provided." >&2
        return 1
    fi

    if [ -n "$1" ]; then
        # If the variable is set, use its value
        retries=$2
    fi

    if [ -n "$2" ]; then
        # If the variable is set, use its value
        sleep_time=$3
    fi

    # Check if the function exists and is executable
    if ! declare -F "$func" >/dev/null 2>&1; then
        console_log "Error: Function '$func' does not exist or is not executable." >&2
        return 1
    fi

    if ! [[ "$retries" =~ ^[0-9]+$ && "$sleep_time" =~ ^[0-9]+$ && "$retries" -ge 0 && "$sleep_time" -ge 0 ]]; then
        console_log "Error: Retries and sleep time must be non-negative integers. lalala" >&2
        return 1
    fi

    local attempt=0

    while [ $attempt -le "$retries" ]; do
        # Execute the function passed as an argument with provided arguments
        console_log "Attempting to run the command \"$func\". Attempt $((attempt + 1))..."
        "$@" && console_log "Attempt $((attempt + 1)) worked." &&return 0  # If the function returns success, exit loop and return 0
        console_log "Attempt $((attempt + 1)) failed. Retrying in $sleep_time seconds..."
        sleep "$sleep_time"
        ((attempt++))
    done
    
    return 1  # Return failure if all retries fail
}

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

    output="$(/opt/mssql-tools/bin/sqlcmd -S "tcp:$host,$port" \
        -U "$user" -P "$password" \
        -d master \
        -Q "set nocount on;$statement;set nocount off" \
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

restore_backups() {
    local host="${1:-localhost}"
    local port="${2:-1433}"
    local user="${3:-sa}"
    local password="$4"
    local bkp_folder="$5"
    local destination="$6"

    local filename full_path filename_no_ext current_dbs dbs_in_bak db_name db_file db_log_name db_log_file restore_stmt

    for file in "$bkp_folder"/*; do
        # Check if the item does not end with .bak extension or is a directory
        if [ ! -f "$file" ] || [[ "$file" != *.bak ]]; then
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

        dbs_in_bak=$(check_dbs_in_bakfile "$host" "$port" "$user" "$password" "$full_path")

        db_name=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -1)

        db_file=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -1)

        db_log_name=$(awk -F "\"*,\"*" '{ n=split($1,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -2 | tail -1)

        db_log_file=$(awk -F "\"*,\"*" '{ n=split($2,a,/\\/); print a[n] }' <<<"$dbs_in_bak" | head -2 | tail -1)

        restore_stmt="RESTORE DATABASE [$filename_no_ext] FROM DISK=N'$full_path' WITH FILE=1, MOVE N'$db_name' TO N'$destination/$db_file', MOVE N'$db_log_name' TO N'$destination/$db_log_file'"

        console_log "DB Name (from file): \"$db_name\""
        console_log "DB File (from file): \"$db_file\""
        console_log "DB Log file name (from file): \"$db_log_name\""
        console_log "DB Log file (from file): \"$db_log_file\""
        console_log "Restore statement: \"$restore_stmt\""
        
        exec_sql "$host" "$port" "$user" "$password" "$restore_stmt"
    done
}