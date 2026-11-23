#!/usr/bin/env bash
# scripts/deploy-k8s.sh
# Deploys QuickBallot to the current kubectl context. Safe to run repeatedly.
#
# Requires: aws, kubectl, helm, terraform, envsubst, jq; terraform/main initialised
# (terraform init -backend-config=../backend.hcl); enable_database and enable_eks applied.
# Optional: AWS_REGION (default eu-north-1), DB_NAME (default quickballot).
# The database password is never printed or passed on a command line.
set -euo pipefail

NAMESPACE=quickballot
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-north-1}}"
DB_NAME="${DB_NAME:-quickballot}"
# Chart and controller versions match; keep in step with the IAM policy file in
# terraform/main/policies/.
ALB_CHART_VERSION=3.6.3
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for tool in aws kubectl helm terraform envsubst jq; do
  command -v "$tool" >/dev/null || { echo "Error: $tool is required." >&2; exit 1; }
done

echo "==> Resolving AWS and database settings"
account_id="$(aws sts get-caller-identity --query Account --output text)"
export ECR_REGISTRY="${account_id}.dkr.ecr.${REGION}.amazonaws.com"

tf_output() {
  terraform -chdir="$ROOT/terraform/main" output -raw "$1" 2>/dev/null || {
    echo "Error: terraform output '$1' is unavailable. Is enable_database applied and terraform initialised?" >&2
    exit 1
  }
}

endpoint="$(tf_output database_endpoint)"
db_host="${endpoint%%:*}"
db_port="${endpoint##*:}"
secret_arn="$(tf_output database_master_user_secret_arn)"
cluster_name="$(tf_output eks_cluster_name)"
vpc_id="$(tf_output vpc_id)"

secret_json="$(aws secretsmanager get-secret-value --region "$REGION" \
  --secret-id "$secret_arn" --query SecretString --output text)"
db_user="$(jq -r .username <<<"$secret_json")"
db_password="$(jq -r .password <<<"$secret_json")"
unset secret_json

echo "==> Using kubectl context: $(kubectl config current-context)"
kubectl apply -f "$ROOT/k8s/namespace.yaml"

echo "==> Applying db-config and db-credentials"
kubectl -n "$NAMESPACE" create configmap db-config \
  --from-literal=DB_HOST="$db_host" \
  --from-literal=DB_PORT="$db_port" \
  --from-literal=DB_NAME="$DB_NAME" \
  --dry-run=client -o yaml | kubectl apply -f -

# The env file comes from a process substitution so the password stays out of
# the argument list and off disk.
kubectl -n "$NAMESPACE" create secret generic db-credentials \
  --from-env-file=<(printf 'DB_USER=%s\nDB_PASSWORD=%s\n' "$db_user" "$db_password") \
  --dry-run=client -o yaml | kubectl apply -f -
unset db_user db_password

echo "==> Running database migration"
kubectl -n "$NAMESPACE" delete job db-migrate --ignore-not-found --wait=true
kubectl kustomize --load-restrictor=LoadRestrictionsNone "$ROOT/k8s/migration" \
  | kubectl apply -f -
if ! kubectl -n "$NAMESPACE" wait --for=condition=complete --timeout=300s job/db-migrate; then
  echo "Error: db-migrate did not complete. Logs:" >&2
  kubectl -n "$NAMESPACE" logs job/db-migrate --tail=50 >&2 || true
  exit 1
fi

echo "==> Installing the AWS Load Balancer Controller"
helm repo add eks https://aws.github.io/eks-charts --force-update >/dev/null
helm repo update eks >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version "$ALB_CHART_VERSION" \
  --set clusterName="$cluster_name" \
  --set region="$REGION" \
  --set vpcId="$vpc_id" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set replicaCount=2
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=300s

echo "==> Applying application manifests"
# envsubst needs the literal variable name, so the single quotes are intended.
# shellcheck disable=SC2016
kubectl kustomize "$ROOT/k8s/" | envsubst '$ECR_REGISTRY' | kubectl apply -f -

echo "==> Waiting for rollouts"
for deployment in vote-api results-api vote-ui; do
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=300s
done

echo "==> Done. Load balancer address (may take a few minutes to appear):"
kubectl -n "$NAMESPACE" get ingress quickballot
