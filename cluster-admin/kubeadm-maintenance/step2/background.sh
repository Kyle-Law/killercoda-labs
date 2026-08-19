#!/bin/bash

# snapshot the current expiration line so we can prove it actually changed -
# once renewed, the old value isn't recoverable from the live cert itself
kubeadm certs check-expiration | grep '^apiserver ' > /root/apiserver-cert-before.txt

touch /tmp/step2-applied
