#!/bin/sh

ffmpeg -re -i $1 -map 0:0 -vcodec h264 -f rtp rtp://$2:$3?pkt_size=1300&rtcpport=$4 &
$(
  while read line ; do
    :
  done
  kill -- -$$
)
