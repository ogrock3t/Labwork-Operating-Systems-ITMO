#!/bin/bash

ps -Ao pid=,etimes= | while read pid time; do
    if [ "$time" -lt "$1" ] && [ "$pid" -ne "$$" ]; then
        kill "$pid" 2>/dev/null && echo "$pid" >> killed.log
    fi
done
