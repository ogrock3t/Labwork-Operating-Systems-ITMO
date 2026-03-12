#!/bin/bash

ps -Ao pid=,etimes= --sort etimes | head -n 1
