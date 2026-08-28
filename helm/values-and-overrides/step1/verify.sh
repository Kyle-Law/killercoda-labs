#!/bin/bash

[ -s /root/message ] || exit 1
grep -q "You will override this message" /root/message || exit 1

exit 0
