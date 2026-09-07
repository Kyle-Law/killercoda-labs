
Apply the kustomization and confirm all three ConfigMaps exist:

```plain
kubectl apply -k /root/app
kubectl get configmap -n demo
```{{exec}}

Now retire one. `legacy-flags` is no longer needed — remove it from `resources.yaml` and re-apply, exactly as you would in a real change.

<br>

<details><summary>Solution</summary>

```plain
cat > /root/app/resources.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  MODE: "production"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-toggles
data:
  NEW_UI: "false"
YAML
```{{exec}}

Confirm it's gone from the render:

```plain
kubectl kustomize /root/app | grep "name:"
```{{exec}}

Apply, and check the cluster:

```plain
kubectl apply -k /root/app
kubectl get configmap -n demo
```{{exec}}

</details>

<br>

## Still there

`kubectl apply` reported success. The render no longer mentions `legacy-flags`. And `legacy-flags` is still in the namespace.

This is not a bug — `apply` reconciles the objects you give it, and you gave it two. The third was simply never mentioned, and "never mentioned" is indistinguishable from "not my concern".

The consequence is that your repository is no longer a description of your cluster. It describes a **subset**, and the difference is invisible from either side.
