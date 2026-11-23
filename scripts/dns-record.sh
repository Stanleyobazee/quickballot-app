#!/usr/bin/env bash
# scripts/dns-record.sh <up|down>
# Creates or removes the alias A record at the zone apex that points to the
# Ingress load balancer. The load balancer belongs to the AWS Load Balancer
# Controller, so Terraform does not manage this record. Safe to run repeatedly.
#
# Requires: aws, kubectl, terraform, jq; terraform/dns initialised.
# Optional: AWS_REGION (default eu-north-1).
set -euo pipefail

NAMESPACE=quickballot
INGRESS=quickballot
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-north-1}}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

action="${1:-}"
case "$action" in
  up | down) ;;
  *)
    echo "Usage: $0 up|down" >&2
    exit 2
    ;;
esac

for tool in aws kubectl terraform jq; do
  command -v "$tool" >/dev/null || { echo "Error: $tool is required." >&2; exit 1; }
done

zone_id="$(terraform -chdir="$ROOT/terraform/dns" output -raw zone_id)"
# The zone name carries a trailing dot, which is the form Route 53 expects.
zone_name="$(aws route53 get-hosted-zone --id "$zone_id" --query HostedZone.Name --output text)"

change_record() {
  local change_id
  change_id="$(aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
    --change-batch "$1" --query ChangeInfo.Id --output text)"
  aws route53 wait resource-record-sets-changed --id "$change_id"
}

if [ "$action" = up ]; then
  echo "==> Waiting for the Ingress load balancer hostname"
  hostname=""
  for _ in $(seq 1 30); do
    hostname="$(kubectl -n "$NAMESPACE" get ingress "$INGRESS" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    [ -n "$hostname" ] && break
    sleep 10
  done
  if [ -z "$hostname" ]; then
    echo "Error: the Ingress has no load balancer hostname after 5 minutes." >&2
    exit 1
  fi

  lb_zone_id="$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?DNSName=='${hostname}'].CanonicalHostedZoneId | [0]" --output text)"
  if [ -z "$lb_zone_id" ] || [ "$lb_zone_id" = None ]; then
    echo "Error: no load balancer found for the Ingress hostname." >&2
    exit 1
  fi

  batch="$(jq -n --arg name "$zone_name" --arg dns "$hostname" --arg lbzone "$lb_zone_id" '{
    Changes: [{
      Action: "UPSERT",
      ResourceRecordSet: {
        Name: $name,
        Type: "A",
        AliasTarget: {HostedZoneId: $lbzone, DNSName: $dns, EvaluateTargetHealth: true}
      }
    }]
  }')"
  echo "==> Upserting the alias record"
  change_record "$batch"
  echo "==> Ready: https://${zone_name%.}"
else
  record="$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    --start-record-name "$zone_name" --start-record-type A --max-items 1 --output json \
    | jq -c --arg name "$zone_name" \
      '.ResourceRecordSets[0] | select(. != null and .Name == $name and .Type == "A" and .AliasTarget != null)')"
  if [ -z "$record" ]; then
    echo "==> No alias record at the zone apex, nothing to do"
    exit 0
  fi
  echo "==> Deleting the alias record"
  change_record "$(jq -n --argjson rr "$record" '{Changes: [{Action: "DELETE", ResourceRecordSet: $rr}]}')"
fi
