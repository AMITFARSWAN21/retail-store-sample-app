# =============================================================================
# PRIVATE ECR REPOSITORIES (one per microservice)
# =============================================================================

locals {
  ecr_services = ["ui", "catalog", "cart", "orders", "checkout"]
}

resource "aws_ecr_repository" "service" {
  for_each = toset(local.ecr_services)

  name = "${var.cluster_name}/${each.key}"

  # A tag can never be overwritten, so a version always means the same image
  image_tag_mutability = "IMMUTABLE"

  # Lets "terraform destroy" delete repos that still contain images
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the 20 most recent tagged images"
        selection = {
          tagStatus      = "any"
          countType      = "imageCountMoreThan"
          countNumber    = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "ecr_repository_urls" {
  description = "ECR repository URL for each microservice"
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "ecr_login_command" {
  description = "Command to log Docker in to the private registry"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
