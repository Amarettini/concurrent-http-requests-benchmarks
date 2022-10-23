#!/bin/bash

export CLIENT_COMPILED=0
export SERVER_IMPL="$1"
export CLIENT_IMPL="$2"
NUM_OF_TASKS="$3" # Number of requests to send by client

# `output` holds the benchmark results seperated by comma (single-line)
output=""


seperator_line() {
  printf "%s\n" "---------------------------------------------------"
}

# Writes the results to a file.
# TODO: export as CSV format
write_result() {
    mkdir -p benchmarks
    filename=benchmarks/$(date -d "today" +"%Y%m%d%H%M").log
    printf "$output\n" > "$filename"

}

# Starts the server receiving our requests, the requests should be handled 
# concurrently as well (although this is implementaion detail which we do 
# not care about).
start_server() {
  case "$1" in
  # flask = python flask server
  "flask")
    cd ./python-server-flask/
    . ./venv/bin/activate
    mkdir -p logs
    # Redirect logs of flask app to ./logs/{timestamp}.log
    flask --app server run >>./logs/$(date -d "today" +"%Y%m%d%H%M").log 2>&1 & SERVER_PID=$! 
    # Wait for server to start in background
    sleep 3
    deactivate
    cd ./..
    ;;
  # async = python asyncio server
  "async")
    printf "Python asyncio server script branch not implemented yet\n"
    exit 1
    ;;
  *)
    printf "Please provide backend type (flask | async)\n"
    ;;
  esac
}

# Starts the client, sending x requests as fast as possible to our server.
start_client() {
  case "$1" in
  "ureq_threads")
    # Compile client once
    if [[ $CLIENT_COMPILED -lt 1 ]]; then
      printf "Compiling client...\n"
      export RUSTFLAGS="$RUSTFLAGS -Awarnings"
      cargo build -r --bin ureq_threads
      CLIENT_COMPILED=1
    fi
    execution_time=$( ./target/release/ureq_threads $NUM_OF_TASKS ) 
    ;;
  "python")
    cd ./python-client/
    . ./venv/bin/activate
    execution_time=$( python client.py $NUM_OF_TASKS )
    deactivate
    cd ./..
    ;;
  *)
    printf "Please provide client type (ureq_threads | python)\n"
    return 1
    ;;
  esac 

  output=$(printf "${output}${execution_time},")
  printf "Executed %04s request(s) in %04dms\n" $NUM_OF_TASKS $execution_time
}

# Stop the server after benchmarks are done.
shutdown_server() {
  kill "$SERVER_PID"
  printf "Shutdown server done."
}


cli_message="Benchmarking number of concurrent requests sent per second in Python VS Rust\n\n."
cli_message="${cli_message}Client: ${CLIENT_IMPL}\n"
cli_message="${cli_message}Server: ${SERVER_IMPL}\n"
printf "$cli_message"
seperator_line

start_server "$SERVER_IMPL"

NUM_OF_TASKS=1
start_client "$CLIENT_IMPL"
NUM_OF_TASKS=10
start_client "$CLIENT_IMPL"
NUM_OF_TASKS=20
start_client "$CLIENT_IMPL" 
NUM_OF_TASKS=40
start_client "$CLIENT_IMPL"
NUM_OF_TASKS=80
start_client "$CLIENT_IMPL"
NUM_OF_TASKS=160
start_client "$CLIENT_IMPL"
NUM_OF_TASKS=320
start_client "$CLIENT_IMPL"

seperator_line

shutdown_server

write_result

