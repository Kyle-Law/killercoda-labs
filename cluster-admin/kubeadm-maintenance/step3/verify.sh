#!/bin/bash

kubeadm token list | grep -q "ci-join-token"
