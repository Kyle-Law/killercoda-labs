
A ServiceAccount named `deployer-sa` is bound to a Role named `deployer-role`, but it still can't **create** Deployments in the `default` namespace. This time the binding isn't the problem — look at what the Role actually grants.

<br>

<details><summary>Tip</summary>

```
kubectl auth can-i create deployments --as=system:serviceaccount:default:deployer-sa
kubectl get rolebinding deployer-sa-binding -o yaml
kubectl get role deployer-role -o yaml
```{{exec}}

</details>

<details><summary>Solution</summary>

A Role's rules are fully mutable — reapplying a corrected one is enough, no need to touch the binding:

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer-role
  namespace: default
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create"]
EOF
```{{exec}}

```
kubectl auth can-i create deployments --as=system:serviceaccount:default:deployer-sa
```{{exec}}

</details>
