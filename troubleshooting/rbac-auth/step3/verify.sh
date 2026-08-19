#!/bin/bash

kubectl auth can-i list nodes --as=system:serviceaccount:default:node-viewer-sa 2>/dev/null | grep -q "^yes$"
