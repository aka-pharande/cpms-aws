output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_region" {
  description = "The region of the EKS cluster"
  value = var.aws_region
}

# Configure kubectl
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.docs.bucket
  description = "S3 bucket for CPMS documents"
}

output "irsa_role_arn" {
  value       = aws_iam_role.s3_irsa_role.arn
  description = "IRSA role used by the ServiceAccount"
}

output "irsa_service_account" {
  value       = "${local.irsa_sa_namespace}/${local.irsa_sa_name}"
  description = "Namespace/name for the annotated ServiceAccount"
}