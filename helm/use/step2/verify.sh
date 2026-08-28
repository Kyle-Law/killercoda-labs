#!/bin/bash

if helm -n team-yellow status apiserver >/dev/null 2>&1; then exit 1; fi

# the other release must be left alone
helm -n team-blue status webserver >/dev/null 2>&1 || exit 1

exit 0
