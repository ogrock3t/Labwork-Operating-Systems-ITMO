#!/bin/bash

max_mem=0
max_pid=0

for pid in /proc/[0-9]*; do
    PID=${pid#/proc/}

    if [[ -r "$pid/status" ]]; then
        mem=$(grep "^VmRSS:" "$pid/status" | awk '{print $2}')

        if [[ -n "$mem" && "$mem" -ge "$max_mem" ]]; then
            max_mem=$mem
            max_pid=$PID
        fi
    fi
done

echo "From /proc: "
echo "${max_pid} ${max_mem}"

echo "From top: "
ps -Ao pid=,rss= --sort rss | tail -n 1
