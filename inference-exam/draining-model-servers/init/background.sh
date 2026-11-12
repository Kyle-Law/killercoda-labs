#!/bin/bash

SIM_IMAGE=ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
CLI_IMAGE=curlimages/curl:8.11.1

mkdir -p /root/answers

# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

# Pull before anything asks for them, so the first rollout is not a download.
for img in $SIM_IMAGE $CLI_IMAGE; do
  crictl pull $img >/dev/null 2>&1 || ctr -n k8s.io images pull $img >/dev/null 2>&1 || true
done

kubectl create namespace serve >/dev/null 2>&1
kubectl config set-context --current --namespace=serve >/dev/null 2>&1

# The stream recorder, run inside the cli Pod. It sends one streamed chat
# completion and prints a single line describing how it ended. echo mode
# returns the prompt, so N words in is N tokens out, one every 500ms.
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: stream
  namespace: serve
data:
  stream.sh: |
    #!/bin/sh
    N=${1:-100}
    OUT=/tmp/stream.$$
    P=$(awk -v n="$N" 'BEGIN{for(i=1;i<=n;i++) printf "w%d ", i}')
    T0=$(date +%s)
    curl -sN --max-time 300 http://chat:8000/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"demo-model\",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"$P\"}]}" > $OUT
    RC=$?
    T1=$(date +%s)
    CHUNKS=$(grep -c '"content"' $OUT)
    if grep -q '\[DONE\]' $OUT; then DONE=yes; else DONE=no; fi
    FIN=$(grep -o '"finish_reason":"[a-z]*"' $OUT | tail -1 | cut -d'"' -f4)
    echo "chunks=$CHUNKS want=$N done=$DONE finish=${FIN:-none} rc=$RC secs=$((T1-T0))"
    rm -f $OUT
YAML

cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat
  namespace: serve
spec:
  replicas: 1
  selector:
    matchLabels: {app: chat}
  template:
    metadata:
      labels: {app: chat}
    spec:
      containers:
      - name: sim
        image: $SIM_IMAGE
        args:
        - --port=8000
        - --model=demo-model
        - --served-model-name=demo-model
        - --mode=echo
        - --time-to-first-token=200ms
        - --inter-token-latency=500ms
        - --max-num-seqs=8
        ports:
        - containerPort: 8000
        readinessProbe:
          httpGet: {path: /health/ready, port: 8000}
          periodSeconds: 2
        livenessProbe:
          httpGet: {path: /health, port: 8000}
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: chat
  namespace: serve
spec:
  selector: {app: chat}
  ports:
  - port: 8000
    targetPort: 8000
---
apiVersion: v1
kind: Pod
metadata:
  name: cli
  namespace: serve
spec:
  containers:
  - name: cli
    image: $CLI_IMAGE
    command: ["sleep", "infinity"]
    volumeMounts:
    - {name: stream, mountPath: /scripts}
  volumes:
  - name: stream
    configMap: {name: stream, defaultMode: 0755}
YAML

# llmstream: one streamed answer, nothing else happening.
cat > /usr/local/bin/llmstream <<'WRAP'
#!/bin/bash
# usage: llmstream [WORDS]   (default 100; one token per word, 500ms each)
R=$(kubectl -n serve exec cli -- /scripts/stream.sh "${1:-100}" 2>&1)
eval "$(echo "$R" | grep -o '[a-z]*=[^ ]*' | tr '\n' ';')" 2>/dev/null
if [ -z "$chunks" ]; then echo "$R"; exit 1; fi
printf 'stream:  %s/%s chunks   [DONE]: %s   finish_reason: %s   curl exit: %s   (%ss)\n' \
  "$chunks" "$want" "$done" "$finish" "$rc" "$secs"
WRAP
chmod +x /usr/local/bin/llmstream

# drill: what a deploy does to an answer in flight. Starts a 100-token stream,
# restarts the Deployment 5 seconds in, and reports how the stream ended and
# how long the old Pod took to go. Each run is appended to /root/drills.log
# with the configuration it ran against; the checks read that file.
cat > /usr/local/bin/drill <<'WRAP'
#!/bin/bash
NS=serve
LOG=/root/drills.log

settled() {
  local n
  n=$(kubectl -n $NS get pods -l app=chat --no-headers 2>/dev/null | wc -l)
  [ "$n" -eq 1 ] || return 1
  kubectl -n $NS get pods -l app=chat \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q true
}

if ! settled; then
  echo -n "waiting for the previous rollout to finish (one Ready chat Pod)"
  for _ in $(seq 1 90); do settled && break; echo -n .; sleep 2; done
  echo
  settled || { echo "chat never settled to one Ready Pod:"; kubectl -n $NS get pods -l app=chat; exit 1; }
fi

OLD=$(kubectl -n $NS get pods -l app=chat -o jsonpath='{.items[0].metadata.name}')
GRACE=$(kubectl -n $NS get deploy chat -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}')
PRESTOP=none
LC=$(kubectl -n $NS get deploy chat -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop}')
# exec first: an exec hook's command can itself contain the word "sleep".
case "$LC" in
  *'"exec":'*)    PRESTOP=exec ;;
  *'"sleep":'*)   PRESTOP=sleep:$(kubectl -n $NS get deploy chat -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop.sleep.seconds}') ;;
  *'"httpGet":'*) PRESTOP=httpGet ;;
esac

echo "old Pod: $OLD   grace: ${GRACE}s   preStop: $PRESTOP"
echo "streaming a 100-token answer (about 50s), restarting the Deployment 5s in..."
TMP=$(mktemp)
( kubectl -n $NS exec cli -- /scripts/stream.sh 100 > "$TMP" 2>&1 ) &
SPID=$!
sleep 5
T0=$(date +%s)
kubectl -n $NS rollout restart deploy/chat >/dev/null
kubectl -n $NS wait --for=delete pod/"$OLD" --timeout=300s >/dev/null 2>&1
GONE=$(( $(date +%s) - T0 ))
wait $SPID
R=$(cat "$TMP"); rm -f "$TMP"
chunks=; eval "$(echo "$R" | grep -o '[a-z]*=[^ ]*' | tr '\n' ';')" 2>/dev/null
if [ -z "$chunks" ]; then echo "the stream did not run:"; echo "$R"; exit 1; fi

printf 'stream:  %s/%s chunks   [DONE]: %s   finish_reason: %s   curl exit: %s\n' \
  "$chunks" "$want" "$done" "$finish" "$rc"
printf 'old Pod: %s gone %ss after the restart\n' "$OLD" "$GONE"
echo "$(date +%s) grace=$GRACE prestop=$PRESTOP chunks=$chunks done=$done rc=$rc gone=$GONE" >> $LOG
WRAP
chmod +x /usr/local/bin/drill

# Shared by the checks. drills_where prints the drill records whose fields all
# match (e.g. drills_where grace=30 done=no); field pulls one value out of a
# record; dep reads the Deployment with a jsonpath.
mkdir -p /usr/local/lib
cat > /usr/local/lib/drain-lab.sh <<'LIB'
drills_where() {
  [ -f /root/drills.log ] || return 0
  local line kv ok
  while read -r line; do
    ok=1
    for kv in "$@"; do
      case " $line " in *" $kv "*) ;; *) ok= ;; esac
    done
    [ -n "$ok" ] && echo "$line"
  done < /root/drills.log
}
field() { echo "$1" | grep -o "$2=[^ ]*" | head -1 | cut -d= -f2-; }
dep() { kubectl -n serve get deploy chat -o jsonpath="$1" 2>/dev/null; }
LIB

BROKEN=
kubectl -n serve rollout status deploy/chat --timeout=240s >/dev/null 2>&1 || BROKEN=1
kubectl -n serve wait --for=condition=Ready pod/cli --timeout=240s >/dev/null 2>&1 || BROKEN=1
[ -n "$BROKEN" ] && touch /tmp/.initbroken
touch /tmp/.initfinished
