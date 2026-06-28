output "dashboard_name" {
  description = "Nome do dashboard CloudWatch"
  value       = module.cloudwatch_monitoring.dashboard_name
}

output "dashboard_arn" {
  description = "ARN do dashboard CloudWatch"
  value       = module.cloudwatch_monitoring.dashboard_arn
}

output "dashboard_url" {
  description = "URL do dashboard CloudWatch"
  value       = module.cloudwatch_monitoring.dashboard_url
}
