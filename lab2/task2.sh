#!/bin/bash

ps -Ao pid=,etimes= --sort etimes | tail -n 1
