#!/bin/sh
bash -c "$@" &
pid=$!
$(
  while read line ; do
    :
  done
  kill -KILL $pid
)
