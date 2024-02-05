#!/bin/bash
WOBPIPE=/tmp/wobpipe
export WOBPIPE

rm -f $WOBPIPE
mkfifo $WOBPIPE
tail -f $WOBPIPE | wob &

