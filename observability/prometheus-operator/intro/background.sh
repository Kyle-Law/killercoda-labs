#!/bin/bash

# server-side apply: the CRDs in this bundle carry very large schemas that can
# exceed the annotation size limit client-side apply relies on
kubectl apply --server-side -f https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.93.1/bundle.yaml

touch /tmp/intro-applied
