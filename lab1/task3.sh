#!/bin/bash

while true
do
    echo "Select a menu item:"
    echo "1. nano"
    echo "2. vi"
    echo "3. links"
    echo "4. exit"

    read choose

    case "$choose" in
        1)
            nano
            ;;
        2)
            vi
            ;;
        3)
            links
            ;;
        4)
            echo "Exit from menu"
            break
            ;;
    esac
done
