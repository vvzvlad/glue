#!/bin/sh

while true; do
   exec tarantool "/usr/local/bin/tarantool-entrypoint.lua" "glue.lua"
   sleep 2
done