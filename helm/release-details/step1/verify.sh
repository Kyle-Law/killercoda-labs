#!/bin/bash

[ -s /root/notes ] || exit 1

# 'helm get notes' output is stable for an installed release, so compare
# against the live release rather than hardcoding chart text
diff <(helm get notes webserver 2>/dev/null) /root/notes >/dev/null 2>&1
