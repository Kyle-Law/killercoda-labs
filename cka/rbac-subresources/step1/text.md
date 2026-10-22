`dev` can read Pods:

```plain
asdev get pods
```{{exec}}

Now ask whether it can read their logs. There is a command built for the question:

```plain
asdev auth can-i get pods/log
```{{exec}}

And then do it:

```plain
asdev logs web
```{{exec}}

Those two disagree. **The task:** find out why, work out the form of `kubectl auth can-i` that tells the truth, and give `dev` the ability to read logs — and **nothing else**. `dev` must still not be able to `exec` into a Pod or `delete` one.

Write the flag that makes `can-i` ask the right question to `/root/answers/step1`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

`can-i` takes `verb resource` or `verb resource/name`. Read the second form carefully, then read what it did with `pods/log`.

```plain
kubectl auth can-i -h | grep -i subresource
```{{exec}}

A rule for a subresource names it in `resources`, next to or instead of the parent:

```plain
kubectl create role -h | grep -i resource=
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
asdev auth can-i get pods --subresource=log
```{{exec}}

> ```
> no
> ```

**`pods/log` was parsed as a Pod named `log`.** The syntax is `verb resource/resourceName`, and `dev` is allowed to `get` Pods, so a Pod called `log` is a perfectly reasonable thing to say yes to. Nothing in the answer says it was a different question from the one you meant. `--subresource=log` asks the real one.

The list view shows the same thing from the other side — there is a `pods` row and no row for any subresource:

```plain
asdev auth can-i --list | grep -E '^(Resources|pods)'
```{{exec}}

Add the missing rule, for `get` on `pods/log` only. `logs` should print the one line the Pod wrote, `started`:

```plain
kubectl create role log-reader --verb=get --resource=pods/log
kubectl create rolebinding log-reader --role=log-reader --serviceaccount=rb:dev
asdev logs web
asdev auth can-i get pods --subresource=log
```{{exec}}

```plain
echo --subresource > /root/answers/step1
```{{exec}}

Both now say yes and the log command works. Check that nothing else came with it:

```plain
asdev auth can-i delete pods
asdev auth can-i create pods --subresource=exec
```{{exec}}

> ```
> no
> no
> ```

</details>
