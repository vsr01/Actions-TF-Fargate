# -----------------------------------------------------------------------------
# GitHub Actions -> AWS (OIDC)
#
# GitHub mints short-lived OIDC tokens; AWS IAM trusts this identity provider and maps
# repository subjects to the deploy role. CI then assumes that role instead of storing
# long-lived AWS access keys in GitHub.
#
# PowerUserAccess allows most services but does not grant IAM API calls. Terraform run
# from GitHub Actions must read/write IAM (roles, OIDC provider, etc.), so IAMFullAccess
# is attached as well. Replace both with a scoped policy when you tighten least privilege.
# -----------------------------------------------------------------------------

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_openid_connect_provider" "github_actions" {
  count = var.use_existing_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.use_existing_github_oidc_provider ? 0 : 1

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = distinct(data.tls_certificate.github_actions.certificates[*].sha1_fingerprint)
}

locals {
  github_oidc_provider_arn = (
    var.use_existing_github_oidc_provider
    ? data.aws_iam_openid_connect_provider.github_actions[0].arn
    : aws_iam_openid_connect_provider.github_actions[0].arn
  )
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy_power_user" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy_iam_full" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}
