#!/bin/bash

EXPECTED=$(kubectl get storageclass -o go-template='{{range .items}}{{if eq (index .metadata.annotations "storageclass.kubernetes.io/is-default-class") "true"}}{{.metadata.name}}{{end}}{{end}}')
[ -n "$EXPECTED" ] || exit 1

ACTUAL=$(tr -d '[:space:]' < /root/default-sc.txt 2>/dev/null)
[ "$ACTUAL" == "$EXPECTED" ]
