#!/bin/sh
# Script for assignment 1
# Author: Robert Kirkman

if [[ -z "$1" || -z "$2" || ! -d "$1" ]]
then
    echo "usage: $0 [filesdir] [searchstr]"
    exit 1
fi

echo "The number of files are $(find $1 -type f | wc -l) and \
the number of matching lines are $(grep -rnI $1 -e $2 | wc -l)"