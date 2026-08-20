#!/bin/bash

kubectl get gatewayclass nginx-gwc >/dev/null 2>&1 || exit 1

GW_CLASS=$(kubectl get gateway web-gateway -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
[ "$GW_CLASS" == "nginx-gwc" ] || exit 1

GW_PORT=$(kubectl get gateway web-gateway -o jsonpath='{.spec.listeners[0].port}' 2>/dev/null)
[ "$GW_PORT" == "80" ] || exit 1

ROUTE_PARENT=$(kubectl get httproute web-route -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
[ "$ROUTE_PARENT" == "web-gateway" ] || exit 1

ROUTE_HOST=$(kubectl get httproute web-route -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null)
[ "$ROUTE_HOST" == "web.example.com" ] || exit 1

ROUTE_BACKEND=$(kubectl get httproute web-route -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
[ "$ROUTE_BACKEND" == "web" ]
