Everything so far was tested with `--as`. That asks the API server what RBAC says about a **name**. It does not show that any credential a real client holds maps to that name — which is a different question, and the one that matters when a Pod's ServiceAccount is the thing in doubt.

A ServiceAccount's real credential is a token. Mint one for `dev` and use it:

```plain
TOKEN=$(kubectl -n rb create token dev)
kubectl --token="$TOKEN" auth whoami
```{{exec}}

Read the username. Then try the thing `dev` must not be able to do:

```plain
kubectl --token="$TOKEN" -n rb exec web -- true && echo "exec worked"
```{{exec}}

**The task:**

1. Write the username `auth whoami` reported on that first attempt to `/root/answers/step5`.
2. Build `/root/dev.kubeconfig`: a kubeconfig whose only credential is `dev`'s token, in namespace `rb`. The check uses it as `dev` would — logs and port-forward must work, and `exec`, `delete`, and anything outside the namespace must not.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

Your own kubeconfig is a *client certificate* for the cluster admin. A request that carries both a certificate and a token is authenticated by the certificate; the token is never consulted.

`kubectl config` can write a kubeconfig of its own with `--kubeconfig=<file>`. Give it a cluster, a user and a context. The cluster's address and CA are in your own config:

```plain
kubectl config view --minify
ls /etc/kubernetes/pki/ca.crt
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl --token="$TOKEN" auth whoami
```{{exec}}

> ```
> ATTRIBUTE   VALUE
> Username    kubernetes-admin
> Groups      [kubeadm:cluster-admins system:authenticated]
> ```

**`--token` did nothing.** The kubeconfig supplies a client certificate, the certificate authenticated the request, and the token was never looked at. Every command in that test ran as cluster-admin. The `exec` succeeded, which is the opposite of what a `dev` token should do, and nothing printed a warning.

```plain
echo kubernetes-admin > /root/answers/step5
```{{exec}}

Build a kubeconfig that has no certificate in it:

```plain
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl -n rb create token dev --duration=4h)
kubectl config --kubeconfig=/root/dev.kubeconfig set-cluster lab --server=$SERVER --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs
kubectl config --kubeconfig=/root/dev.kubeconfig set-credentials dev --token=$TOKEN
kubectl config --kubeconfig=/root/dev.kubeconfig set-context lab --cluster=lab --user=dev --namespace=rb
kubectl config --kubeconfig=/root/dev.kubeconfig use-context lab
kubectl --kubeconfig=/root/dev.kubeconfig auth whoami
```{{exec}}

> ```
> Username    system:serviceaccount:rb:dev
> Groups      [system:serviceaccounts system:serviceaccounts:rb system:authenticated]
> ```

Now try what `dev` should and should not be able to do:

```plain
kubectl --kubeconfig=/root/dev.kubeconfig logs web
kubectl --kubeconfig=/root/dev.kubeconfig exec web -- true
kubectl --kubeconfig=/root/dev.kubeconfig get nodes
```{{exec}}

> The first works. The other two are Forbidden, naming `system:serviceaccount:rb:dev` as the user.

**What each test proves.** `--as` proves what RBAC says about a name. A token proves that a credential maps to that name, and that RBAC then decides for the right identity. The first test costs nothing to run; the second is the only one that can catch the case where the thing you tested was not the thing in use. `kubectl auth whoami` is how you tell the difference.

A token made by `create token` expires — after an hour unless you ask for longer, as here.

</details>
