
`web-cert` is `Ready`. That is a claim about cert-manager having done its job, and nothing else.

Bring up the workload that uses it — the manifest is already written, because nginx is not the lesson here:

```plain
kubectl apply -f /root/web.yaml
```{{exec}}

```plain
kubectl -n app rollout status deploy/web
```{{exec}}

Now make a request to it:

```plain
webcurl
```{{exec}}

That fails, and the certificate is not the problem. Work out which side is refusing and why, then **write the certificate that fixes it to `/root/answers/ca.crt`** and prove it:

```plain
webcurl /root/answers/ca.crt
```{{exec}}

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

`curl` exit code 60 is not a server error. The server is serving exactly what you asked it to:

```plain
servedcert
```{{exec}}

Issuance and trust are two different problems, and step 2 only solved the first. The client has never been given any reason to believe `lab-root-ca`.

cert-manager already put what you need next to the leaf:

```plain
kubectl -n app get secret web-cert-tls -o jsonpath='{.data}' | tr ',' '\n'
```{{exec}}

Two of those three keys are certificates, and **both of them will make `curl` succeed**. Only one of them is the right answer. Compare them before you pick:

```plain
kubectl -n app get secret web-cert-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -enddate -ext basicConstraints
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl -n app get secret web-cert-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > /root/answers/ca.crt
```{{exec}}

```plain
webcurl /root/answers/ca.crt
```{{exec}}

Nothing changed on the server. The same nginx, serving the same certificate, on the same connection — the only thing that moved was what the client was willing to believe.

**Handing the client `tls.crt` instead also works**, and that is worth knowing, because it is a trap rather than an alternative. OpenSSL treats anything in the trust store as an anchor, including the exact leaf being presented, so the request succeeds and the setup looks correct. Then compare the two certificates:

```plain
kubectl -n app get secret web-cert-tls -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -subject -enddate -ext basicConstraints
```{{exec}}

The leaf is `CA:FALSE`, carries no name of its own worth trusting, and expires in 90 days. The CA is `CA:TRUE` and good for a year. A trust store built from leaves has to be rebuilt on every renewal, of every service, separately — and it grants trust to exactly one certificate rather than to the authority that issues them. Trusting the CA covers everything it will ever sign, including certificates that do not exist yet.

That is what makes the next step possible at all.

</details>
