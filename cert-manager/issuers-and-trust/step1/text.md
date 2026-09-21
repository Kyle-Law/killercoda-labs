
In namespace `app` there is a `Certificate` called `app-cert`. It was applied cleanly — no error, no rejection — and it has never produced a Secret.

```plain
kubectl -n app get certificate app-cert
```{{exec}}

Get it issuing.

Before you fix anything, find out *where cert-manager wrote down what is wrong*, because the answer is not on the `Certificate`. Read the `Certificate`'s own status and you will be told `Issuing certificate as Secret does not exist` — which sounds like progress, and is the only thing it will ever say.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

A `Certificate` is a standing request. The attempt to satisfy it is a **different object**, created per issuance, and that is where a failure is recorded:

```plain
kubectl -n app get certificaterequest
```{{exec}}

```plain
kubectl -n app describe certificaterequest
```{{exec}}

Then look at what exists, and where:

```plain
kubectl get issuer,clusterissuer -A
```{{exec}}

</details>

<details><summary>Solution</summary>

The `CertificateRequest` says:

```plain
Referenced "Issuer" not found: issuer.cert-manager.io "lab-selfsigned" not found
```

`lab-selfsigned` does exist — in namespace `pki`. An `Issuer` is a **namespaced** object, and `issuerRef` has no namespace field: a `Certificate` can only name an `Issuer` in its own namespace, or a `ClusterIssuer`, which has no namespace at all.

So either give `app` its own issuer:

```plain
kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: lab-selfsigned
  namespace: app
spec:
  selfSigned: {}
YAML
```{{exec}}

...or make the existing one cluster-scoped and point `app-cert` at that instead. Either is a real fix; the first is one object.

cert-manager retries on its own — within a few seconds:

```plain
kubectl -n app get certificate,certificaterequest,secret
```{{exec}}

</details>
