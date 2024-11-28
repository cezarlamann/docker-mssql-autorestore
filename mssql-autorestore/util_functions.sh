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
