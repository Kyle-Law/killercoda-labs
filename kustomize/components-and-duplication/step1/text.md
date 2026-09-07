
Look at what you've inherited:

```plain
find /root/app -type f | sort
diff /root/app/overlays/staging/monitoring-patch.yaml /root/app/overlays/prod/monitoring-patch.yaml && echo "IDENTICAL"
```{{exec}}

The same patch, byte for byte, in two places.

Now do the thing that goes wrong. Monitoring moved to port **9102**. Update it **everywhere** it appears, and confirm both environments render the new port.

<br>

<details><summary>Solution</summary>

```plain
sed -i 's/9090/9102/' /root/app/overlays/staging/monitoring-patch.yaml
sed -i 's/9090/9102/' /root/app/overlays/prod/monitoring-patch.yaml
```{{exec}}

```plain
for e in staging prod; do
  echo "--- $e ---"
  kubectl kustomize /root/app/overlays/$e | grep "prometheus.io/port"
done
```{{exec}}

</details>

<br>

## Two edits for one change

That was two files for a single logical change, with nothing enforcing that they stay identical. Nothing in Kustomize would have complained if you had updated only one — you'd simply have staging scraping 9102 and prod still on 9090, and no error anywhere.

Now scale that mentally: three environments, and monitoring, HA, and a debug sidecar as optional features. That's a directory per combination, and every feature change is a sweep across all of them.
