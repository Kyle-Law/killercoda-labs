A colleague wrote a Role for `ops` and says it covers everything about Pods:

```plain
kubectl get role ops-pods -o yaml | sed -n '/^rules/,$p'
```{{exec}}

Reasonable on its face: `get` and `create`, on `pods/*`. Ask what `ops` can do:

```plain
asops auth can-i --list | grep -E '^(Resources|pods)'
```{{exec}}

The rule is right there in the list. Now try it:

```plain
asops get pods
asops logs web
asops exec web -- true
```{{exec}}

**The task:** `ops` must be able to see Pods, read their logs, `exec` into them and port-forward to them — and must **not** be able to create or delete Pods. Fix `ops-pods`.

Write how many of those four things the original Role allowed to `/root/answers/step4`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

RBAC understands `*` as a whole resource and `*/log` as "that subresource of anything". It does not understand `pods/*`.

An RBAC rule has one list of verbs. If you want `get` on some resources and `create` on others, that is two rules, not one.

</details>

<details><summary>Solution</summary>

```plain
asops get pods
asops logs web
asops exec web -- true
asops auth can-i get pods --subresource=log
```{{exec}}

> Forbidden, Forbidden, Forbidden, `no`. **`pods/*` is not a wildcard.** The rule is accepted, listed and ignored: no error, no warning, nothing granted. Not even `get pods`, since `pods/*` does not match `pods` either, and a plain `get pods` is a `list`, which the Role did not name. The only wildcard spellings RBAC matches are `*` (everything) and `*/subresource`.

The tempting repair is to list all four resources against `get` and `create`. That still leaves `asops get pods` Forbidden, because seeing every Pod is a `list` and the Role never granted one, and it lets `ops` `create` Pods, which was ruled out. Each verb belongs on different resources, so they need separate rules:

```plain
kubectl patch role ops-pods --type=json -p='[{"op":"replace","path":"/rules","value":[
 {"apiGroups":[""],"resources":["pods"],"verbs":["get","list"]},
 {"apiGroups":[""],"resources":["pods/log"],"verbs":["get"]},
 {"apiGroups":[""],"resources":["pods/exec","pods/portforward"],"verbs":["create"]}]}]'
asops get pods
asops logs web
asops exec web -- true
asops auth can-i create pods
```{{exec}}

> The first three work; the last is `no`.

```plain
echo 0 > /root/answers/step4
```{{exec}}

A related one worth knowing, because it is the more common mistake. `verbs: ["*"]` on `resources: ["pods"]` is every verb on the Pod **object**: it includes `delete`, and it does *not* include `pods/log` or `pods/exec`. The wildcard stops at the slash.

</details>
