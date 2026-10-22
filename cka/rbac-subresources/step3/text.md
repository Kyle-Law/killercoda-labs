`dev` can read Pods and read their logs. Now it needs to reach the web server in `web` from where you are sitting, with `port-forward`:

```plain
asdev port-forward web 8080:80
```{{exec}}

It fails. Read the whole line before deciding what the problem is.

**The task:** give `dev` the ability to port-forward to Pods — and still **not** to `exec`.

Write the resource the error ends on to `/root/answers/step3`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The error starts with `error upgrading connection`, which sounds like a network or TLS fault. The sentence it carries is about permission, and it is at the far end of the line.

The same pattern as `exec`: a verb on a subresource.

</details>

<details><summary>Solution</summary>

```plain
asdev port-forward web 8080:80
```{{exec}}

> ```
> error: error upgrading connection: unable to upgrade connection: pods "web" is forbidden: User "system:serviceaccount:rb:dev" cannot create resource "pods/portforward" in API group "" in the namespace "rb"
> ```

**`error upgrading connection` is how a refused port-forward starts.** `port-forward` and `exec` both ask the API server to switch the connection to a streaming protocol, and when authorisation refuses, that is the layer that reports it, so the message opens with a complaint about the connection (`exec` words it `unable to upgrade connection`). The sentence that matters is the last one. Here it is `create` on `pods/portforward`.

```plain
kubectl create role portforward --verb=create --resource=pods/portforward
kubectl create rolebinding portforward --role=portforward --serviceaccount=rb:dev
asdev port-forward web 8080:80 &
sleep 2
curl -s localhost:8080
kill %1
```{{exec}}

> ```
> Forwarding from 127.0.0.1:8080 -> 80
> Forwarding from [::1]:8080 -> 80
> Handling connection for 8080
> ok
> ```

`dev` already had `get` on `pods` from the first Role, which is why this took one rule rather than two. Without that, `port-forward` fails exactly as `exec` did in the last step: `cannot get resource "pods"`.

```plain
echo pods/portforward > /root/answers/step3
asdev auth can-i create pods --subresource=exec
```{{exec}}

> `no`. The ability to forward a port is not the ability to run a command.

</details>
