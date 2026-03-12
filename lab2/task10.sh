#!/bin/bash

awk -F'[ :=]+' '
{
    ppid=$4
    art=$6

    if (NR==1) {
        cur_ppid=ppid
    }

    if (ppid != cur_ppid) {
        print "Average_Running_Children_of_ParentID=" cur_ppid " is " sum/count
        sum=0
        count=0
        cur_ppid=ppid
    }

    print $0
    sum+=art
    count++
}
END {
    if (count > 0)
        print "Average_Running_Children_of_ParentID=" cur_ppid " is " sum/count
}
' result.txt > result_2.txt
