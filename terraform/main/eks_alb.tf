# IAM for the AWS Load Balancer Controller, granted through EKS Pod Identity.
# The controller itself is installed by scripts/deploy-k8s.sh.

# Policy document vendored unchanged from the controller project:
#   https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.6.3/docs/install/iam_policy.json
# Controller version: v3.6.3. SHA-256: 16f232c9d9f79366fe949c4550ad517a202380058a9e48d45a4e215044a20a6a
# Update the file, its name and the Helm chart version in scripts/deploy-k8s.sh together.
resource "aws_iam_policy" "alb_controller" {
  count  = var.enable_eks ? 1 : 0
  name   = "${local.eks_name}-alb-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller-v3.6.3.json")
}

data "aws_iam_policy_document" "alb_controller_trust" {
  count = var.enable_eks ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.eks_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust[0].json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.alb_controller[0].name
  policy_arn = aws_iam_policy.alb_controller[0].arn
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller[0].arn

  depends_on = [aws_eks_addon.before_nodes]
}
