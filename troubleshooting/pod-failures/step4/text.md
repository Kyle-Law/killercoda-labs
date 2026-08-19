
A Pod named `probe-pod` in the `default` namespace is `Running` but never becomes `Ready` — `kubectl get pod probe-pod` shows `0/1`. Find out why, then fix the Pod so it reaches `READY 1/1`.

<br>

<details><summary>Tip</summary>

```
kubectl describe pod probe-pod
```{{exec}}

Check the `Events` section for readiness probe failures, then compare the probe's path against what the container actually serves:

```
kubectl exec probe-pod -- wget -qO- localhost/healthz
kubectl exec probe-pod -- wget -qO- localhost/
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl get pod probe-pod -o yaml > /root/probe-pod.yaml
```{{exec}}

Edit `/root/probe-pod.yaml` and change `readinessProbe.httpGet.path` from `/healthz` to `/`.

```
kubectl delete pod probe-pod
kubectl apply -f /root/probe-pod.yaml
```{{exec}}

</details>
