#!/bin/bash

N=$1

for pid in $(ps -Ao pid=); do
    time=$(ps -p "$pid" -o etimes=)

    if [[ -n "$time" && "$time" -gt "$N" ]]; then
        renice +5 -p "$pid"
    fi
done
