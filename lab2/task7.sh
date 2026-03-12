#!/bin/bash

# strace -i ./troubleshooting_amd64

strace -e trace=network -o troubleshooting_network.log ./troubleshooting_amd64

strace -e trace=file -o troubleshooting_file.log ./troubleshooting_amd64
