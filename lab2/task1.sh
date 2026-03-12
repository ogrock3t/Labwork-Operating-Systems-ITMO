#!/bin/bash

ps a | awk '$3 ~ /^[RSDZT]/ { print $1 }'
