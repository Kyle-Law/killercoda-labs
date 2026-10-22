`runner` is a CI job's ServiceAccount. It has no permissions at all. It needs to do one thing: `exec` into the `web` Pod in this namespace.

```plain
asrunner exec web -- ls
```{{exec}}

**The task:** give `runner` that ability and **nothing else**. It must not be able to list Pods, read their logs, or delete them.

The obvious Role has one rule. Write it, bind it, and try again. Then read the error that comes back — it is not the one you just fixed.

Write the rule that the **second** error asked for, as `verb resource`, to `/root/answers/step2`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

`exec` is a `create` on `pods/exec`. That is the first rule. When it is in place, the next refusal names a different resource and a different verb: read it to the end.

`kubectl exec` has to find the Pod before it can open a session in it.

</details>

<details><summary>Solution</summary>

```plain
kubectl create role exec-only --verb=create --resource=pods/exec
kubectl create rolebinding exec-only --role=exec-only --serviceaccount=rb:runner
asrunner exec web -- ls
```{{exec}}

> ```
> Error from server (Forbidden): pods "web" is forbidden: User "system:serviceaccount:rb:runner" cannot get resource "pods" in API group "" in the namespace "rb"
> ```

**A second rule, on a different resource.** `exec` needs `create` on `pods/exec` *and* `get` on `pods`: the first opens the session, the second is the lookup of which Pod to open it in. A Role with only the first is useless, and the error does not mention `exec` at all.

Add only what was named. `get`, not `list` or `watch`, and on `pods`, not `pods/log`:

```plain
kubectl patch role exec-only --type=json -p='[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["pods"],"verbs":["get"]}}]'
asrunner exec web -- ls
```{{exec}}

> ```
> bin
> dev
> etc
> ...
> www
> ```

Now confirm the limits:

```plain
asrunner get pods
asrunner logs web
asrunner auth can-i delete pods
```{{exec}}

> `get pods` with no name is a `list`, and `runner` only has `get`, so it is Forbidden. So are the logs. `delete` is `no`.

```plain
echo "get pods" > /root/answers/step2
```{{exec}}

</details>
