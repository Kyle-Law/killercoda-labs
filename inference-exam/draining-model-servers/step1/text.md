First, what an answer looks like when nothing is happening to the server. Twenty words, so about ten seconds:

```plain
llmstream 20
```{{exec}}

> ```
> stream:  20/20 chunks   [DONE]: yes   finish_reason: stop   curl exit: 0   (10s)
> ```

Every chunk, a closing `[DONE]`, a `finish_reason`, curl exits `0`. That is what a complete answer looks like on the wire.

Now the same kind of answer, five times longer, with a deploy landing in the middle of it:

```plain
drill
```{{exec}}

It takes about a minute. Compare its result line with the one above.

**The task:** the answer was cut and nobody got an error. Work out how long Kubernetes gave the old Pod between deciding to stop it and killing it, and write that number of seconds to `/root/answers/step1`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

`drill` printed how long the old Pod took to disappear. The field that sets the limit is in the Pod template, even though the manifest that created it never mentioned it: the API server filled it in.

```plain
kubectl get deploy chat -o yaml | grep -n -i grace
```{{exec}}

```plain
kubectl explain pod.spec.terminationGracePeriodSeconds
```{{exec}}

</details>

<details><summary>Solution</summary>

> ```
> old Pod: chat-74fbc5758d-5dssk   grace: 30s   preStop: none
> streaming a 100-token answer (about 50s), restarting the Deployment 5s in...
> stream:  72/100 chunks   [DONE]: no   finish_reason: none   curl exit: 18
> old Pod: chat-74fbc5758d-5dssk gone 32s after the restart
> ```

**About three quarters of the answer (72 to 75 tokens across runs), no `[DONE]`, no `finish_reason`.** curl's exit 18 is *partial file*: the server had promised more and closed the connection instead. There is no status code in that result to alert on. The response began with `200 OK` fifty seconds ago, and every proxy and access log between here and the user recorded a success.

The old Pod lasted 32 seconds after the restart. The limit is in its template:

```plain
kubectl get deploy chat -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}{"\n"}'
```{{exec}}

> ```
> 30
> ```

You did not write that field; the API server defaulted it. The sequence it governs is: the new Pod becomes Ready, the old one is removed from the Service's endpoints and sent `SIGTERM`, and if its container is still running 30 seconds later the kubelet sends `SIGKILL`. The rest of the 32 seconds is the new Pod starting up first.

```plain
kubectl get events --sort-by=.lastTimestamp | grep -E 'Killing' | tail -2
```{{exec}}

```plain
echo 30 > /root/answers/step1
```{{exec}}

A web server finishes its in-flight requests in a few milliseconds of those 30 seconds. This one needed another 20 seconds of answer. The obvious fix is to give it more time, and that is the next step.

</details>
