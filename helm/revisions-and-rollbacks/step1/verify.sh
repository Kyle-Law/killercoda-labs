#!/bin/bash

[ -s /root/history ] || exit 1

# all three revisions must be listed
for r in 1 2 3; do
  grep -qE "^${r}[[:space:]]" /root/history || exit 1
done

exit 0
