# Killercoda Labs

CKA exam-prep scenarios, organized by topic so a single lab can be reused across multiple certification course groups instead of being duplicated per-cert:

- `storage/` — PV/PVC, StorageClass, ConfigMap/Secret volumes
- `workloads/` — Deployments, rollouts/rollbacks, CronJobs, scheduling constraints
- `probes/` — liveness vs readiness vs startup: what each one actually does on failure, the outages from confusing them, and why readiness is what makes a rolling update safe at all
- `networking/` — Services, Ingress, Gateway API
- `troubleshooting/` — Pods, control plane, Services/DNS, nodes, RBAC, resource usage
- `cluster-admin/` — etcd backup/restore, kubeadm maintenance
- `helm/` — Helm end to end: releases, chart versions, values, rollbacks, safe deploys, templating
- `gitops/` — Argo CD: sync/health, drift & self-heal, sync waves & hooks, Helm/Kustomize sources, history & rollback, App-of-Apps & ApplicationSet, a declarative Helm-backed App-of-Apps, the full UI on a multi-node cluster, a self-hosted Gitea source, Gitea webhooks with auto-sync/self-heal/prune; plus standalone Argo Rollouts canary & blue-green
- `observability/` — the operator pattern, Prometheus Operator, ServiceMonitors
- `ai-workloads/` — running, observing, scheduling and queueing AI workloads on Kubernetes, without a GPU
- `packaging/` — Helm beyond the basics (failed upgrades and recovery, values file precedence)
- `kiamol/` — labs following *Learn Kubernetes in a Month of Lunches*, one per day, covering what the topic-first labs above don't already

`archive/` holds older example scenarios (2022–2024) kept for reference but no longer actively maintained.

Based on https://github.com/killercoda/scenario-examples — see these in action at https://killercoda.com/examples, and scenario authoring docs at https://killercoda.com/creators.

For grouping scenarios into courses check https://github.com/killercoda/scenario-examples-groups
