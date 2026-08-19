#!/bin/bash

kubectl auth can-i list pods --as=system:serviceaccount:default:viewer-sa 2>/dev/null | grep -q "^yes$"
