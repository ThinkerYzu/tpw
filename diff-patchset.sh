#!/bin/bash

shopt -s extglob

V2=$(tpw.sh ver|awk -- '{print $2; }')
V1=v$((${V2:1}-1))
NUM_PATCHES=$(tpw.sh lsfix|wc -l)

for i in $(seq.sh $NUM_PATCHES); do echo "patch $((i+1)) -----------"; NO_TMP=1 diff-patch-ver.sh $V1 $V2 $((i+1)); done
