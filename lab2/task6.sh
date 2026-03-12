#!/bin/bash

ps -Ao pid=,rss= --sort=rss

ps -Ao rss | awk '{sum+=$1} END {print "Total ram: " sum}'
