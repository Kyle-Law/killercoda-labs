#!/bin/bash

[ -s /root/before ] || exit 1
grep -q "You will override this message" /root/before || exit 1

exit 0
