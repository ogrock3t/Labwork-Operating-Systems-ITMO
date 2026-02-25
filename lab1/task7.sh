#!/bin/bash

grep -rhoE '[A-Za-z0-9._-]+@[A-Za-z0-9._-]+\.[A-Za-z]' /etc | tr '\n' ',' > email.lst
