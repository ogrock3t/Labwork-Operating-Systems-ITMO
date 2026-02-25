#!/bin/bash

man bash | tr '[:space:]' '\n' | grep -E '.{4,}' | sort | uniq -c | sort -nr | head -n 3
