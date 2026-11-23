#!/usr/bin/env bash
# scripts/teardown-k8s.sh
# Removes the DNS record, the Ingress and the load balancer it created, before
# any Terraform teardown. An orphaned load balancer or its security groups
# block deletion of the VPC. Nothing else is uninstalled, and this script never
# runs terraform apply.
#
# Requires: aws, kubectl, terraform; terraform/main and terraform/dns initialised.
# Optional: AWS_REGION (default eu-north-1).
set -euo pipefail

NAMESPACE=quickballot
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-north-1}}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for tool in aws kubectl terraform; do
  command -v "$tool" >/dev/null || { echo "Error: $tool is required." >&2; exit 1; }
done

tf_output() {
  terraform -chdir="$ROOT/terraform/main" output -raw "$1" 2>/dev/null || {
    echo "Error: terraform output '$1' is unavailable in terraform/main." >&2
    exit 1
  }
}

cluster_name="$(tf_output eks_cluster_name)"
vpc_id="$(tf_output vpc_id)"
echo "==> Using kubectl context: $(kubectl config current-context)"

load_balancers() {
  aws resourcegroupstaggingapi get-resources --region "$REGION" \
    --resource-type-filters elasticloadbalancing:loadbalancer \
    --tag-filters "Key=ingress.k8s.aws/cluster,Values=${cluster_name}" \
    --query 'ResourceTagMappingList[].ResourceARN' --output text
}

security_groups() {
  aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=vpc-id,Values=${vpc_id}" "Name=tag-key,Values=elbv2.k8s.aws/cluster" \
    --query 'SecurityGroups[].GroupId' --output text
}

# wait_until_empty <description> <function>: polls every 10 seconds for up to 5 minutes.
wait_until_empty() {
  local remaining=""
  for _ in $(seq 1 30); do
    remaining="$("$2")"
    [ -z "$remaining" ] && return 0
    sleep 10
  done
  echo "Error: $1 still present after 5 minutes: $remaining" >&2
  exit 1
}

echo "==> Removing the DNS record"
"$ROOT/scripts/dns-record.sh" down

echo "==> Deleting the Ingress"
kubectl -n "$NAMESPACE" delete ingress quickballot --ignore-not-found --wait=true

echo "==> Waiting for the load balancer to be removed"
wait_until_empty "load balancers for cluster ${cluster_name}" load_balancers

echo "==> Waiting for the controller security groups to be removed"
wait_until_empty "controller security groups in ${vpc_id}" security_groups

echo "==> Kubernetes-managed AWS resources are gone. Run next, by hand:"
echo "    terraform -chdir=terraform/main plan -out=tfplan -var enable_eks=false -var enable_database=false -var enable_nat_gateway=false"
echo "    terraform -chdir=terraform/main apply tfplan"
