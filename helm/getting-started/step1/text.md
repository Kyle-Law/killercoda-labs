
Reference: [quickstart](https://helm.sh/docs/intro/quickstart) · [install](https://helm.sh/docs/intro/install) · [using helm](https://helm.sh/docs/intro/using_helm)

<br>

We're working with an Ubuntu VM that has never seen anything "Kubernetes" before.

## Install K3s

Helm needs a running Kubernetes cluster, so install K3s first:

```plain
curl -sfL https://get.k3s.io | sh -
```{{exec}}

```plain
kubectl get node
```{{exec}}

<br>

## Install Helm

```plain
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```{{exec}}

Helm reads the cluster connection from `KUBECONFIG`, and K3s writes its config to a non-default path:

```plain
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc
```{{exec}}

```plain
helm version
```{{exec}}
