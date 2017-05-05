#!/bin/sh

raspivid -t 0 -w 320 -h 240 -n -fps 24 -o - | ffmpeg -re -i pipe:0 -map 0:0 -vcodec h264 -f rtp rtp://$1:$2?pkt_size=1300&rtcpport=$3 &
$(
  while read line ; do
    :
  done
  kill -- -$$
)
