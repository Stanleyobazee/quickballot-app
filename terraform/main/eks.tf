locals {
  eks_name = "${var.project}-eks"

  # Add-ons that must exist before the nodes can become ready, and add-ons
  # that need running nodes.
  eks_addons_before_nodes = var.enable_eks ? toset(["vpc-cni", "eks-pod-identity-agent"]) : toset([])
  eks_addons_after_nodes  = var.enable_eks ? toset(["coredns", "kube-proxy"]) : toset([])
}

# ── Control plane ───────────────────────────────────────────────────────────

data "aws_iam_policy_document" "eks_cluster_trust" {
  count = var.enable_eks ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.eks_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust[0].json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Created before the cluster so that the retention setting applies from the
# first log event.
resource "aws_cloudwatch_log_group" "eks" {
  count             = var.enable_eks ? 1 : 0
  name              = "/aws/eks/${local.eks_name}/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "main" {
  count    = var.enable_eks ? 1 : 0
  name     = local.eks_name
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster[0].arn

  # Add-ons are managed explicitly below instead of being installed at creation.
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_public_access_cidrs
  }

  # Leave standard support by upgrading instead of moving to extended support,
  # which is billed at a higher hourly rate.
  upgrade_policy {
    support_type = "STANDARD"
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  lifecycle {
    precondition {
      condition     = var.enable_nat_gateway
      error_message = "enable_eks requires enable_nat_gateway = true: nodes in the private subnets need outbound access to join the cluster and pull images."
    }

    precondition {
      condition     = var.eks_admin_role_arn != null
      error_message = "enable_eks requires eks_admin_role_arn: bootstrap_cluster_creator_admin_permissions is false, so without an admin access entry nobody can use the cluster."
    }

    precondition {
      condition     = length(var.eks_public_access_cidrs) > 0
      error_message = "enable_eks requires a non-empty eks_public_access_cidrs: the public API endpoint must be limited to explicit CIDR ranges."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.eks,
    aws_iam_role_policy_attachment.eks_cluster,
  ]
}

# ── Cluster administrator ───────────────────────────────────────────────────

resource "aws_eks_access_entry" "admin" {
  count         = var.enable_eks ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  principal_arn = var.eks_admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  count         = var.enable_eks ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  principal_arn = aws_eks_access_entry.admin[0].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ── Managed node group ──────────────────────────────────────────────────────

data "aws_iam_policy_document" "eks_node_trust" {
  count = var.enable_eks ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count              = var.enable_eks ? 1 : 0
  name               = "${local.eks_name}-node"
  assume_role_policy = data.aws_iam_policy_document.eks_node_trust[0].json
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = var.enable_eks ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ]) : toset([])

  role       = aws_iam_role.eks_node[0].name
  policy_arn = each.value
}

resource "aws_eks_node_group" "main" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.eks_name}-default"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.private[*].id

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = [var.eks_node_instance_type]
  disk_size      = 20

  scaling_config {
    min_size     = var.eks_node_count
    desired_size = var.eks_node_count
    max_size     = var.eks_node_count
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node,
    aws_eks_addon.before_nodes,
    # Nodes need the NAT route to reach the internet when they boot.
    aws_route.private_nat,
  ]
}

# ── Add-ons ─────────────────────────────────────────────────────────────────

data "aws_eks_addon_version" "main" {
  for_each           = setunion(local.eks_addons_before_nodes, local.eks_addons_after_nodes)
  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.main[0].version
  most_recent        = true
}

resource "aws_eks_addon" "before_nodes" {
  for_each      = local.eks_addons_before_nodes
  cluster_name  = aws_eks_cluster.main[0].name
  addon_name    = each.key
  addon_version = data.aws_eks_addon_version.main[each.key].version
}

resource "aws_eks_addon" "after_nodes" {
  for_each      = local.eks_addons_after_nodes
  cluster_name  = aws_eks_cluster.main[0].name
  addon_name    = each.key
  addon_version = data.aws_eks_addon_version.main[each.key].version

  depends_on = [aws_eks_node_group.main]
}

# ── OIDC provider ───────────────────────────────────────────────────────────

# thumbprint_list is optional in provider v6; AWS validates the issuer's
# certificate chain itself.
resource "aws_iam_openid_connect_provider" "eks" {
  count          = var.enable_eks ? 1 : 0
  url            = aws_eks_cluster.main[0].identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}
