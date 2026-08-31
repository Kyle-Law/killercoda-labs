
Argo CD is installed — the full install this time, UI included. Right now `argocd-server`'s Service is a plain `ClusterIP`: reachable from inside the cluster, invisible from your browser.

Change its type to `NodePort`, on port `30080` specifically. Then open the UI and log in — username `admin`, password already sitting in `/root/argocd-admin-password.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl get svc argocd-server -n argocd
```{{exec}}

```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```{{exec}}

That assigns a **random** NodePort, not `30080` specifically — check what you got, then patch the actual port mapping to force it. A Service's `ports[].nodePort` field can be set explicitly, the same as any other field.

</details>

<details><summary>Solution</summary>

```
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080,"protocol":"TCP"},{"name":"https","port":443,"targetPort":8080,"protocol":"TCP"}]}}'
```{{exec}}

```
kubectl get svc argocd-server -n argocd
```{{exec}}

`80:30080/TCP` — that's the one that matters, since the server's running in `--insecure` (plain HTTP) mode.

[ACCESS ARGO CD]({{TRAFFIC_HOST1_30080}})

```
cat /root/argocd-admin-password.txt
```{{exec}}

Log in as `admin` with that password. You're looking at an empty Applications dashboard — nothing's been created yet.

</details>
