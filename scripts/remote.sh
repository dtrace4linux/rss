#! /bin/sh
host=$1 ; shift

echo "$@" | telnet $host 22222
