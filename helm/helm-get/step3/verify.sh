#!/bin/bash

[ -s /root/manifest ] || exit 1

diff <(helm get manifest webserver 2>/dev/null) /root/manifest >/dev/null 2>&1
