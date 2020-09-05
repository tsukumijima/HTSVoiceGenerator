#!/bin/bash

echo $1 | tools/open_jtalk/bin/open_jtalk \
    -x tools/open_jtalk/dic/ \
    -m $2 \
    -s 48000 \
    -a 0.545 \
    -r 1.15 \
    -ow $3 \
