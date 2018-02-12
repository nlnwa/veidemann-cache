#!/bin/sh
echo "Start helper $*" >&2
while read s; do
  if [ "${s::1}" = "L" ]; then
    echo ${s:1} >&2
  fi
done
