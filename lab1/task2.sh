#!/bin/bash

result=""

while true
do
    read input
    if [[ $input = "q" ]]; then
        echo "$result"
        exit 0
    else
        result+="$input"
    fi
done
