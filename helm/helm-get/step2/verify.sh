#!/bin/bash

[ -s /root/values ] || exit 1

diff <(helm get values webserver 2>/dev/null) /root/values >/dev/null 2>&1
