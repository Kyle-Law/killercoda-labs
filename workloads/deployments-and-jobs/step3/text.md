
Create a CronJob named `log-cleanup` that runs every minute, using the `busybox` image, executing a command that just prints something and exits. Confirm it has completed at least one successful run.

<br>

<details><summary>Tip</summary>

```
kubectl create cronjob --help
kubectl get cronjob,jobs,pods -w
```{{exec}}

CronJob schedules have a 1-minute granularity — this step needs a short real wait for the first run to fire.

</details>

<details><summary>Solution</summary>

```
kubectl create cronjob log-cleanup --image=busybox --schedule="*/1 * * * *" -- sh -c "echo cleanup ran at \$(date)"
```{{exec}}

```
kubectl get cronjob log-cleanup -w
```{{exec}}

</details>
