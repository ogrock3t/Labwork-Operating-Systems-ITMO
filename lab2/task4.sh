#!/bin/bash

sleep 10000 &

PID=$!

cd /proc/$PID/

tail -n 5 ./stack

grep -E '^(Name|PPid|Kthread)' ./status

grep -E '^(Tgid|Pid)' ./status
