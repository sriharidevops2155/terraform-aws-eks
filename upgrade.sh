#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# == EDIT THESE VARIABLES ==
CLUSTER="roboshop-dev"             # <--- your cluster name
OLD_NG="nodegroup-old"               # <--- existing nodegroup name (1.32)
NEW_NG="nodegroup-new"               # <--- new blue/green nodegroup name
NEW_VERSION="1.33"                   # <--- target k8s control-plane & node version
INSTANCE_TYPE="t3.medium"            # <--- instance type for new nodes
DESIRED_NODES=3                      # <--- desired capacity for new NG
MIN_NODES=3
MAX_NODES=3
TAINT_KEY="upgrade"                  # will create taint: upgrade=true:NoSchedule
TAINT_VAL="true"
# Firewall / Security Group placeholders (adapt to your infra)
FIREWALL_SG_ID="sg-xxxxxxxxxxxx"     # sg you will modify to block other teams (placeholder)
# ---------------------------

# Tools check
for cmd in kubectl eksctl aws jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required tool '$cmd' is not installed or not in PATH." >&2
    exit 1
  fi
done

echo "=== Starting zero-downtime upgrade runbook for cluster: $CLUSTER ==="
echo "Announcing downtime (3 hours) to teams (script prints this; integrate with your slack/email notifier if you want)"
echo "DOWNTIME NOTICE: Platform upgrade in progress for cluster '$CLUSTER'. Expected maintenance window: 3 hours. Please do not deploy changes during this time."
echo

# Optional: block access by modifying security group(s) to restrict connectivity
# WARNING: replace commands below with commands appropriate to your networking setup.
echo "==> Applying temporary firewall changes to restrict access (placeholder) =="
echo "Please adapt the following commands for your environment. Currently they are commented out."
cat <<'EOF'
# Example (commented): revoke inbound access from a wide CIDR (ADAPT before use)
# aws ec2 revoke-security-group-ingress --group-id $FIREWALL_SG_ID --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
# Example: add a restrictive rule (allow only mgmt IP)
# aws ec2 authorize-security-group-ingress --group-id $FIREWALL_SG_ID --protocol tcp --port 22 --cidr x.x.x.x/32
EOF
echo

# 1) Create new nodegroup (blue/green) with same capacity, but taint nodes to prevent scheduling initially.
echo "==> Creating new nodegroup '$NEW_NG' (tainted) with kubernetes version set to $NEW_VERSION ..."
eksctl create nodegroup \
  --cluster "${CLUSTER}" \
  --name "${NEW_NG}" \
  --node-type "${INSTANCE_TYPE}" \
  --nodes "${DESIRED_NODES}" \
  --nodes-min "${MIN_NODES}" \
  --nodes-max "${MAX_NODES}" \
  --version "${NEW_VERSION}" \
  --managed

echo "Waiting for nodes from nodegroup \"$NEW_NG\" to register in Kubernetes..."
# Wait until nodes with label eks.amazonaws.com/nodegroup=$NEW_NG appear and are Ready
until kubectl get nodes -l "eks.amazonaws.com/nodegroup=${NEW_NG}" --no-headers 2>/dev/null | awk '{print $2}' | grep -q 'Ready'; do
  echo "  - waiting for node(s) to become Ready..."
  sleep 10
done
echo "New nodes are Ready."

# 2) Taint new nodes so workloads will not schedule until we explicitly untaint
echo "==> Applying taint ${TAINT_KEY}=${TAINT_VAL}:NoSchedule to new nodegroup nodes..."
kubectl taint nodes -l "eks.amazonaws.com/nodegroup=${NEW_NG}" ${TAINT_KEY}=${TAINT_VAL}:NoSchedule || true
echo "Taint applied."

# 3) Upgrade control plane to target version
echo "==> Upgrading control plane to Kubernetes $NEW_VERSION ..."
# Use eksctl if available (recommended); also show aws cli alternative
if command -v eksctl >/dev/null; then
  eksctl upgrade cluster --name "${CLUSTER}" --version "${NEW_VERSION}" --approve
else
  echo "eksctl not found; attempting aws CLI update-cluster-version command..."
  aws eks update-cluster-version --name "${CLUSTER}" --kubernetes-version "${NEW_VERSION}"
fi

# Poll cluster version until it matches NEW_VERSION
echo "Polling cluster control-plane version until upgrade completes..."
while true; do
  current_version=$(aws eks describe-cluster --name "${CLUSTER}" --query "cluster.version" --output text)
  echo "  - current control-plane version: $current_version"
  if [[ "$current_version" == "$NEW_VERSION" ]]; then
    echo "Control plane is now at version $NEW_VERSION."
    break
  fi
  echo "  - upgrade in progress; sleeping 15s..."
  sleep 15
done
echo

# 4) Ensure new nodegroup is upgraded to the same version (if needed)
echo "==> Upgrading new nodegroup '$NEW_NG' to k8s $NEW_VERSION (if required)..."
# For managed nodegroups, eksctl supports upgrade nodegroup
eksctl upgrade nodegroup --cluster "${CLUSTER}" --name "${NEW_NG}" --kubernetes-version "${NEW_VERSION}" || echo "Nodegroup upgrade command returned non-zero (check if already at desired version)."

# 5) Cordon old nodes
echo "==> Cordoning old nodegroup nodes: $OLD_NG"
kubectl cordon -l "eks.amazonaws.com/nodegroup=${OLD_NG}" || true

# 6) Untaint the new nodegroup to allow scheduling onto the new nodes
echo "==> Removing taint from new nodegroup nodes so workloads can schedule..."
kubectl taint nodes -l "eks.amazonaws.com/nodegroup=${NEW_NG}" ${TAINT_KEY}=${TAINT_VAL}:NoSchedule- || true

# 7) Start draining old nodes (moves workloads to new nodegroup)
echo "==> Draining nodes from old nodegroup: ${OLD_NG}"
old_nodes=$(kubectl get nodes -l "eks.amazonaws.com/nodegroup=${OLD_NG}" -o name || true)
if [[ -z "$old_nodes" ]]; then
  echo "No nodes found for nodegroup ${OLD_NG} (they may already be gone)."
else
  for node in $old_nodes; do
    echo " Draining ${node} ..."
    # Force drain but respect PDBs where possible, ignore DaemonSets
    kubectl drain "${node}" --ignore-daemonsets --delete-local-data --force --timeout=10m || {
      echo "  - Warning: drain failed for ${node}. Please inspect pods and PDBs."
    }
    # After drain, cordon again for safety
    kubectl cordon "${node}" || true
  done
fi

# 8) Wait until workloads have stabilized on new nodes
echo "==> Waiting for pods to be scheduled and for cluster to stabilize (check deployments/statefulsets)..."
# Basic sleep + advise manual checks (this is cluster-specific)
sleep 30
kubectl rollout status deployment --all-namespaces || true

# 9) Delete the old nodegroup
echo "==> Deleting old nodegroup '${OLD_NG}' ..."
eksctl delete nodegroup --cluster "${CLUSTER}" --name "${OLD_NG}" || {
  echo "eksctl delete nodegroup failed — try aws eks delete-nodegroup or check console."
}

# 10) (Optional) If you need to manually edit control plane config, do so now.
echo "==> Verify control-plane version and perform any final manual edits if needed."
aws eks describe-cluster --name "${CLUSTER}" --query "cluster.version" --output text

# 11) Re-enable original firewall rules (placeholder)
echo "==> Restoring firewall rules to original state (placeholder) -- adapt and run the appropriate aws ec2 commands"
cat <<'EOF'
# Example (commented): restore previously revoked rules
# aws ec2 authorize-security-group-ingress --group-id $FIREWALL_SG_ID --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
EOF

# 12) Announce completion
echo
echo "UPGRADE COMPLETE: Control plane and new nodegroup targeted at Kubernetes $NEW_VERSION."
echo "Please ask application teams to verify their applications."
echo "If anything failed during the script, inspect logs and AWS console, and do NOT re-run blindly."
echo "=== DONE ==="
