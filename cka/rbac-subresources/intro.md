<br>

A `Role` that grants `get` on `pods` reads like it covers everything you can do to a Pod. It covers the Pod **object**. `kubectl logs`, `kubectl exec` and `kubectl port-forward` are different resources (`pods/log`, `pods/exec`, `pods/portforward`) with rules of their own, and the command most people reach for to check them gives the wrong answer.

Already running in namespace `rb`: a Pod called `web` that serves one page, and three ServiceAccounts.

| ServiceAccount | What it has | What it is for |
|---|---|---|
| `dev` | a Role that reads Pods | steps 1, 3 and 5 |
| `runner` | nothing at all | step 2 |
| `ops` | a Role a colleague wrote | step 4 |

You never log in as them. You **impersonate** them with `--as`, from your admin session, which asks the API server what *they* would be allowed to do. Three short commands do that for you:

```plain
asdev get pods
```{{exec}}

is exactly

```plain
kubectl -n rb --as=system:serviceaccount:rb:dev get pods
```

and `asrunner` and `asops` are the same for the other two. Step 5 is about what that does and does not prove.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
