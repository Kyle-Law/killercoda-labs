
Take the deny off again:

```plain
kubectl delete netpol api-deny
```{{exec}}

Now answer the question you would actually need answered before locking down a real service: **everything currently talking to `api` — who is it?**

Then look at the list and decide whether anything on it should not be there. Write that workload's name to `/root/answers/step3.txt`.

<br>

<details><summary>Tip</summary>

Flows carry the source name, so this is a matter of extracting and counting it:

```plain
flows --since 60s --to-pod api | grep to-endpoint | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -rn
```{{exec}}

Use `--since`, not `--last`. `--last N` returns the last N flows *in the buffer*, which may be minutes old; `--since` bounds it by time, which is what "currently" means.

</details>

<details><summary>Solution</summary>

```plain
kubectl delete netpol api-deny
sleep 15
flows --since 60s --to-pod api | grep to-endpoint | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -rn
```{{exec}}

> ```
>      56 default/web-79fbb8dd79-8z5ff
>      43 default/scanner-69574656d5-rkj9l
> ```

**`web` is expected. `scanner` is not.** It has been calling `api` every three seconds since before this lab started, and nothing in the cluster's configuration would have told you — it needs no permission to do so, because until step 2 there was no policy at all.

```plain
echo "scanner - unauthorised workload calling api" > /root/answers/step3.txt
```{{exec}}

Look at what it is doing:

```plain
flows --since 60s --to-pod api --from-pod scanner | head -4
kubectl get deploy scanner -o jsonpath='{.spec.template.spec.containers[0].command}{"\n"}'
```{{exec}}

> Polling `http://api/` in a loop.

Widen the window and you may also catch an entry that is a **bare IP with no Pod name**, something like `7 10.244.0.155`:

```plain
flows --since 10m --to-pod api | grep to-endpoint | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -rn
```{{exec}}

Those appear intermittently, because whatever sends them is on a slower timer than `web` and `scanner`. They are traffic that identity resolution could not attribute to a Pod — typically the node itself, running a health check. **On a real cluster these are exactly the entries to investigate before writing a policy**, because a default-deny cuts them off and a failing health check looks like the application broke, not like a policy you just applied.

> **This is the workflow the exam objective is really about.** Nobody can write a correct allow-list from memory for a service that has been running for a year. You observe what actually happens first, *then* write policy to match it. Flow logs are what make that possible — and doing it in the other order is how a default-deny takes down something nobody remembered was calling.

</details>
