
Argo CD and Gitea are both installed. Both are `ClusterIP` right now — reachable from inside the cluster, invisible from your browser.

Expose both:

- `argocd-server` (namespace `argocd`) → NodePort `30080`
- `gitea` (namespace `gitea`) → NodePort `30300`

Then log into both. Argo CD: username `admin`, password in `/root/argocd-admin-password.txt`. Gitea: credentials in `/root/gitea-admin-credentials.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl get svc -n argocd argocd-server
kubectl get svc -n gitea gitea
```{{exec}}

Same technique both times — patch `spec.type` to `NodePort` and pin the exact `nodePort` you want on the relevant port, rather than taking whatever gets assigned at random.

</details>

<details><summary>Solution</summary>

```
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080,"protocol":"TCP"},{"name":"https","port":443,"targetPort":8080,"protocol":"TCP"}]}}'
```{{exec}}

```
kubectl patch svc gitea -n gitea -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":3000,"targetPort":3000,"nodePort":30300,"protocol":"TCP"},{"name":"ssh","port":22,"targetPort":22,"protocol":"TCP"}]}}'
```{{exec}}

```
kubectl get svc -n argocd argocd-server
kubectl get svc -n gitea gitea
```{{exec}}

[ACCESS ARGO CD]({{TRAFFIC_HOST1_30080}}) — log in with `admin` and whatever's in `/root/argocd-admin-password.txt`.

[ACCESS GITEA]({{TRAFFIC_HOST1_30300}}) — browse it straight away, no login needed yet; the repo you're about to create will be public.

</details>
