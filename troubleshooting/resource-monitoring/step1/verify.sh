#!/bin/bash

ANSWER=$(tr -d '[:space:]' < /root/top-cpu-pod.txt 2>/dev/null)
[ "$ANSWER" == "high-cpu" ]
