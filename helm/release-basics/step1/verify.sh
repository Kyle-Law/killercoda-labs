#!/bin/bash

[ -f /root/releases ] || exit 1

# both releases live in non-default namespaces, so only 'helm ls -A' finds them
grep -q webserver /root/releases || exit 1
grep -q apiserver /root/releases || exit 1

exit 0
