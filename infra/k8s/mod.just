set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/infra/k8s'

[private]
default:
    just -l kube

[doc('Browse a PVC')]
browse-pvc namespace claim:
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}


[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[doc('Snapshot VolSync PVCs')]
snapshot:
    ts=$(date +%s); \
    total=$(kubectl get replicationsources --no-headers -A | wc -l | tr -d ' '); \
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p "{\"spec\":{\"trigger\":{\"manual\":\"$ts\"}}}"; \
    done; \
    echo "waiting for $total snapshots to finish..."; \
    until [ "$(kubectl get replicationsources -A -o json | jq --arg ts "$ts" '[.items[] | select(.status.lastManualSync==$ts)] | length')" -eq "$total" ]; do sleep 20; done; \
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" patch replicationsources "$name" --type json -p '[{"op":"remove","path":"/spec/trigger/manual"}]'; \
    done; \
    kubectl get replicationsources -A -o json | jq -r '.items[] | select(.status.latestMoverStatus.result != "Successful") | "FAILED: \(.metadata.namespace)/\(.metadata.name) = \(.status.latestMoverStatus.result)"'

[doc('Sync ExternalSecrets')]
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --overwrite es "$name" force-sync="$(date +%s)"; \
    done


[doc('View a secret')]
view-secret namespace secret:
    kubectl view-secret -n {{ namespace }} {{ secret }}
