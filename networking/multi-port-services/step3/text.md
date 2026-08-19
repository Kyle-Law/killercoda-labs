
Create a Service named `external-api` of type `ExternalName` pointing at `example.com`. Confirm that resolving `external-api` from inside the cluster (using the `dns-client` Pod) returns a record pointing at `example.com` — no selector, no endpoints, just a DNS alias.

<br>

<details><summary>Tip</summary>

```
kubectl explain service.spec.externalName
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: example.com
EOF
```{{exec}}

```
kubectl exec dns-client -- nslookup external-api
```{{exec}}

</details>
