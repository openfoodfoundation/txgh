#!/bin/sh

if nc -z localhost 9292; then
    #echo "Port 9292 is in use. Assuming that the server is running already."
    exit 0
fi

#echo "Starting txgh server in background."
. config/secret/env.sh
mkdir -p log
bundle exec puma -p 9292 > "log/puma-$(date --rfc-3339=seconds).log" &

