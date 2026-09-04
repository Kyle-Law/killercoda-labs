
Change the message in the base to `updated message v2` and re-apply the dev overlay. Watch what happens to the Pods — you didn't touch the image, the replica count, or anything else in the Deployment.

Then set `generatorOptions.disableNameSuffixHash: true` in the base and change the message **twice more**, applying each time. Predict what each apply does to the Pods before you look — the two are not the same, and the reason matters.

<br>

<details><summary>Tip</summary>

Watch the Pod names across the first change:

```plain
kubectl get pods -l app=shop -w
```{{exec}}

For the second half, add this to `/root/app/base/kustomization.yaml`:

```yaml
generatorOptions:
  disableNameSuffixHash: true
```

Then change the message again, apply, and compare `kubectl get configmap` against `shopmsg dev-shop`. Pay attention to what `kubectl apply` says about the **deployment** each time.

</details>

<details><summary>Solution</summary>

```plain
sed -i 's|ui-message=.*|ui-message=updated message v2|' /root/app/base/kustomization.yaml
kubectl apply -k /root/app/overlays/dev
```{{exec}}

> `configmap/dev-shop-config-<newhash> created` and `deployment.apps/dev-shop configured`.

```plain
kubectl rollout status deployment/dev-shop --timeout=120s
shopmsg dev-shop
```{{exec}}

New content produced a new hash, which produced a new ConfigMap name, which changed the Deployment's pod template, which is a rollout. You got a config-change deployment for free, with no annotation trick and nothing watching anything.

Now throw it away:

```plain
cat > /root/app/base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
  - service.yaml

generatorOptions:
  disableNameSuffixHash: true

configMapGenerator:
  - name: shop-config
    literals:
      - ui-message=updated message v3
EOF
kubectl apply -k /root/app/overlays/dev
kubectl rollout status deployment/dev-shop --timeout=120s
```{{exec}}

> `deployment.apps/dev-shop configured` — it **still rolled**. Not because the content changed, but because the ConfigMap's *name* did: `dev-shop-config-<hash>` became plain `dev-shop-config`, so the reference in the pod template changed one last time. That is the final free rollout you will get.

From here the name never changes again. Change the value once more and watch:

```plain
sleep 8
POD_BEFORE=$(shoppod dev-shop)
echo "watching $POD_BEFORE"
sed -i 's|ui-message=.*|ui-message=updated message v4|' /root/app/base/kustomization.yaml
kubectl apply -k /root/app/overlays/dev
```{{exec}}

> `configmap/dev-shop-config configured` — and this time **`deployment.apps/dev-shop unchanged`**.

```plain
sleep 15
echo "pod before: $POD_BEFORE"
echo "pod after:  $(shoppod dev-shop)"
echo "ConfigMap says: $(kubectl get cm dev-shop-config -o jsonpath='{.data.ui-message}')"
echo -n "App serves:     "; shopmsg dev-shop
```{{exec}}

The same Pod name before and after, no restart. The ConfigMap holds `updated message v4`; the application is still serving `v3`, and will keep doing so until something unrelated happens to restart it — a node drain, a scale event, an unrelated deploy next quarter.

Nothing failed. No probe fired, no event was logged, `kubectl apply` reported success. That is what makes it dangerous: **the deployed state and the running state disagree, silently and indefinitely.**

<br>

<details><summary>Info: when a ConfigMap change <em>does</em> reach a running Pod</summary>

It depends entirely on how the Pod consumes it:

- **`env` / `envFrom`** — never. Environment variables are fixed when the container starts. This is the case you just saw.
- **volume mount** — the file updates on its own, usually within a minute. Whether the *application* notices is a separate question: most read config once at startup and never look again.
- **`subPath` volume mount** — never. A known, easily-missed exception.

The hash suffix sidesteps the whole question by making a config change into a normal rolling update, which works identically for all three.

</details>

</details>
