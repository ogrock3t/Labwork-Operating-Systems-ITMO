#!/bin/bash

if [[ "$PWD" == "$HOME" ]]; then
    echo "$HOME"
    exit 0
else
    echo "Error: this script isn't run from home directory"
    exit 1
fi
