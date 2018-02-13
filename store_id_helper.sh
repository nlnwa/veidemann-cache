#!/bin/sh
echo "Store ID helper $*" >&2
while read s; do
  STORE_ID="$(echo ${s} | cut -d' ' -f2)$(echo ${s} | cut -d' ' -f1)"
  echo "STORE ID: ${STORE_ID}" >&2
  echo "OK store-id=\"${STORE_ID}\""
done
