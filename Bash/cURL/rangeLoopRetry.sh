#!/bin/bash

########
# Purpose to call an endpoint with a range of values within body.
## This one is expecting a 204 status code. If it isn't retrieved it will try 3 times.
## After 3 times failure, it will log the issue in a csv file.
## It will stop script next morning to not affect clients.
##
### Why ? Well, I was wasting a lot of time creating csv files to feed to Postman. It was a waste of my time.
### Postman had issues and limitations.
##
#######

# Constants
URL='https://7/ls'
TOKEN='eyJ'
BATCH=100

# Input arguments
from=$1
to=$2
range=100

# End time in epoch seconds WARNING: 7 am next day. so if you start at midnight, it will be 31 hours later.
end_time=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date -v+1d +%Y-%m-%d) 07:00:00" "+%s")
#echo "$end_time"

# Counter variables
current_from=$from
current_to=$((current_from+range))
attempts=0
iteration=1

# Loop through ranges
while [ $current_to -le "$to" ]
do
    # Check if end time has been reached
    current_time=$(date +%s)
    if (( current_time > end_time )); then
        echo "Script ended prematurely at iteration $iteration: from $current_from to $current_to"
        exit
    fi


    echo "Iteration $iteration: from $current_from to $current_to"

    # Make the curl request
    response=$(curl --max-time 120 --location "$URL" \
                    --header 'Content-Type: application/json' \
                    --header "Authorization: Bearer $TOKEN" \
                    --data '{
                        "fromId" : '$current_from',
                        "toId" : '$current_to',
                        "batchSize": '$BATCH'
                    }' \
                    -w "%{http_code}" \
                    2>/dev/null)

    # Check response code
    response_code=$(echo "$response" | tail -n 1)

    if [ "$response_code" -ne 204 ]; then
        # Retry up to 3 times
        while [ $attempts -lt 3 ]
        do
            attempts=$((attempts+1))
            sleep 5
            response=$(curl --max-time 120 --location "$URL" \
                                --header 'Content-Type: application/json' \
                                --header "Authorization: Bearer $TOKEN" \
                                --data '{
                                    "fromId" : '$current_from',
                                    "toId" : '$current_to',
                                    "batchSize": '$BATCH'
                                }' \
                                -w "%{http_code}" \
                                2>/dev/null)

            response_code=$(echo "$response" | tail -n 1)
            if [ "$response_code" -eq 204 ]; then
                break
            fi
        done

        # If all attempts failed, log the error
        if [ "$response_code" -ne 204 ]; then
            echo "$current_from,$current_to,$BATCH" >> errors.csv
        fi
    fi

    # Update counter variables
    current_from=$current_to
    current_to=$((current_to+range))
    attempts=0
    iteration=$((iteration+1))
done
