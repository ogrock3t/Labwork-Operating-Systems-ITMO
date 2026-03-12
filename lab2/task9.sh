#!/bin/bash

> result.txt

for pid in /proc/[0-9]*; do
    PID=${pid#/proc/}

    if [[ -r $pid/status && -r $pid/sched ]]; then
        PPid=$(grep "^PPid:" "$pid/status" | awk '{print $2}')
        sum=$(grep "sum_exec_runtime" "$pid/sched" | awk '{print $3}')
        nr=$(grep "nr_switches" "$pid/sched" | awk '{print $3}')

        if [[ -n "$sum" && -n "$nr" && "$nr" -ne 0 ]]; then
            ART=$(awk "BEGIN {print $sum / $nr}")
            echo "ProcessID=$PID : Parent_ProcessID=$PPid : Average_Running_Time=$ART" >> result.txt
        fi
    fi
done

sort -t'=' -k3 -n result.txt -o result.txt
