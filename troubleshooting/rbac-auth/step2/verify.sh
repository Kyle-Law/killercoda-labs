#!/bin/bash

kubectl auth can-i create deployments --as=system:serviceaccount:default:deployer-sa 2>/dev/null | grep -q "^yes$"
