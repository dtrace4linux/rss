#! /bin/sh
host=$1 ; shift

echo GET "$@" | telnet $host 22222
