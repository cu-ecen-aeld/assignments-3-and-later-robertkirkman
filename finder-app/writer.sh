#!/bin/bash
# Script for assignment 1
# Author: Robert Kirkman

if [[ -z "$1" || -z "$2" ]]
then
    echo "usage: $0 [writefile] [writestr]"
    exit 1
fi

if ! install -D <(echo $2) $1
then
    echo "failed to write \"$2\" to $1"
    exit 1
fi