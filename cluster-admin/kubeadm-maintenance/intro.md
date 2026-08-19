
<br>

Three routine cluster-admin tasks, all safe and purely additive — nothing in this lab is broken for you to fix:

1. Granting RBAC access to a real **User** — Kubernetes has no first-class User object; a user is just a name your auth method presents, and RBAC binds to that name directly
2. Renewing a control-plane certificate with `kubeadm certs renew`
3. Creating a bootstrap token for joining a new node with `kubeadm token create`
