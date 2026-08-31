# Killercoda Labs

CKA exam-prep scenarios, organized by topic so a single lab can be reused across multiple certification course groups instead of being duplicated per-cert:

- `storage/` — PV/PVC, StorageClass, ConfigMap/Secret volumes
- `workloads/` — Deployments, rollouts/rollbacks, CronJobs, scheduling constraints
- `networking/` — Services, Ingress, Gateway API
- `troubleshooting/` — Pods, control plane, Services/DNS, nodes, RBAC, resource usage
- `cluster-admin/` — etcd backup/restore, kubeadm maintenance
- `helm/` — Helm end to end: releases, chart versions, values, rollbacks, safe deploys, templating
- `gitops/` — Argo CD: sync/health, drift & self-heal, sync waves & hooks, Helm/Kustomize sources, history & rollback, App-of-Apps & ApplicationSet; plus standalone Argo Rollouts canary & blue-green
- `observability/` — the operator pattern, Prometheus Operator, ServiceMonitors
- `packaging/` — Helm beyond the basics (failed upgrades and recovery, values file precedence)
- `kiamol/` — labs following *Learn Kubernetes in a Month of Lunches*, one per day, covering what the topic-first labs above don't already

`archive/` holds older example scenarios (2022–2024) kept for reference but no longer actively maintained.

Based on https://github.com/killercoda/scenario-examples — see these in action at https://killercoda.com/examples, and scenario authoring docs at https://killercoda.com/creators.

For grouping scenarios into courses check https://github.com/killercoda/scenario-examples-groups
