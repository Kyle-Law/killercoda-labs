
CronJob `backup-job` is running on a schedule. Pause it — without deleting it — so it stops firing new runs.

Then, while it's paused, manually trigger **one** run right now, as if you needed an on-demand backup outside the schedule. Create it as a Job named `backup-manual-1`, and confirm that run completes successfully.

<br>

<details><summary>Tip</summary>

```
kubectl explain cronjob.spec.suspend
kubectl create job --help
```{{exec}}

`suspend` is a mutable field on the CronJob — no delete/recreate needed. `kubectl create job <name> --from=cronjob/<cronjob-name>` is how you fire an ad-hoc run using the CronJob's own template.

</details>

<details><summary>Solution</summary>

```
kubectl patch cronjob backup-job --type merge -p '{"spec":{"suspend":true}}'
```{{exec}}

```
kubectl create job backup-manual-1 --from=cronjob/backup-job
```{{exec}}

```
kubectl wait --for=condition=complete job/backup-manual-1 --timeout=60s
kubectl logs job/backup-manual-1
```{{exec}}

</details>
