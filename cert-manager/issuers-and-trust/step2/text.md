
A self-signed issuer gives every `Certificate` its own unrelated root, which is useless the moment two workloads have to trust each other. What you want is one internal CA that signs everything.

Build it, in two objects and then a third:

1. A `Certificate` with `isCA: true` and `commonName: lab-root-ca`, signed by a self-signed issuer — this is the CA keypair itself.
2. A `ClusterIssuer` named `lab-ca`, of type `ca`, backed by the Secret that `Certificate` wrote.
3. A `Certificate` named `web-cert` in namespace `app`, for `web.app.svc.cluster.local`, secret name `web-cert-tls`, issued by `lab-ca`.

Put the CA keypair wherever seems right to you. **Expect the first attempt to fail**, and when it does, read the `ClusterIssuer`'s status before changing anything — the error it gives is the interesting part of this step, and it is a lie by omission.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl get clusterissuer lab-ca -o jsonpath='{.status.conditions[0].message}'
```{{exec}}

It will tell you a Secret is not found. Go and look at that Secret — it is there, and `kubectl get` will show it to you quite happily.

So the question is not whether the Secret exists. It is **which namespace cert-manager looked in**, and why a cluster-scoped object could not have looked anywhere else:

```plain
kubectl -n cert-manager get deploy cert-manager -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n'
```{{exec}}

</details>

<details><summary>Solution</summary>

A `ClusterIssuer` has no namespace of its own, so it has no namespace to resolve a `secretName` against. cert-manager gives it one: `--cluster-resource-namespace`, which defaults to the namespace cert-manager itself runs in. Every Secret a `ClusterIssuer` references — a CA keypair, an ACME account key, cloud credentials — is read from there and nowhere else.

The message never mentions this. It says `secrets "root-ca-tls" not found` with no namespace attached, while the Secret sits in plain sight in whichever namespace you created it in.

So the CA keypair belongs in `cert-manager`:

```plain
kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: lab-selfsigned
  namespace: cert-manager
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: lab-root-ca
  secretName: root-ca-tls
  duration: 8760h
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: lab-selfsigned
    kind: Issuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lab-ca
spec:
  ca:
    secretName: root-ca-tls
YAML
```{{exec}}

```plain
kubectl get clusterissuer lab-ca
```{{exec}}

`Signing CA verified`. Now ask it for a leaf:

```plain
kubectl apply -f - <<'YAML'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-cert
  namespace: app
spec:
  secretName: web-cert-tls
  dnsNames:
  - web.app.svc.cluster.local
  issuerRef:
    name: lab-ca
    kind: ClusterIssuer
YAML
```{{exec}}

```plain
kubectl -n app get certificate web-cert
```{{exec}}

Note what just happened across a namespace boundary: the CA lives in `cert-manager`, the leaf lives in `app`, and nothing in `app` can read the CA's private key. That is the whole reason `ClusterIssuer` reads from one fixed namespace rather than from the caller's.

</details>
