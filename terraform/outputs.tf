# Property Upkeep Records System - Terraform Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

# Database outputs
output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "RDS instance database name"
  value       = aws_db_instance.main.db_name
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

# Redis outputs
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}

# SQS outputs
output "sqs_document_processing_queue_url" {
  description = "URL of the document processing SQS queue"
  value       = aws_sqs_queue.document_processing.url
}

output "sqs_document_processing_queue_arn" {
  description = "ARN of the document processing SQS queue"
  value       = aws_sqs_queue.document_processing.arn
}

output "sqs_notifications_queue_url" {
  description = "URL of the notifications SQS queue"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_notifications_queue_arn" {
  description = "ARN of the notifications SQS queue"
  value       = aws_sqs_queue.notifications.arn
}

output "sqs_report_generation_queue_url" {
  description = "URL of the report generation SQS queue"
  value       = aws_sqs_queue.report_generation.url
}

output "sqs_report_generation_queue_arn" {
  description = "ARN of the report generation SQS queue"
  value       = aws_sqs_queue.report_generation.arn
}

# S3 outputs
output "s3_documents_bucket_name" {
  description = "Name of the documents S3 bucket"
  value       = aws_s3_bucket.documents.bucket
}

output "s3_documents_bucket_arn" {
  description = "ARN of the documents S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

output "s3_backups_bucket_name" {
  description = "Name of the backups S3 bucket"
  value       = aws_s3_bucket.backups.bucket
}

output "s3_backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  value       = aws_s3_bucket.backups.arn
}

output "s3_alb_logs_bucket_name" {
  description = "Name of the ALB logs S3 bucket"
  value       = aws_s3_bucket.alb_logs.bucket
}

# Secrets Manager outputs
output "secrets_database_arn" {
  description = "ARN of the database secrets"
  value       = aws_secretsmanager_secret.database.arn
}

output "secrets_redis_arn" {
  description = "ARN of the Redis secrets"
  value       = aws_secretsmanager_secret.redis.arn
}

output "secrets_jwt_arn" {
  description = "ARN of the JWT secrets"
  value       = aws_secretsmanager_secret.jwt.arn
}

# IAM outputs
output "application_role_arn" {
  description = "ARN of the application IAM role"
  value       = aws_iam_role.application.arn
}

output "application_role_name" {
  description = "Name of the application IAM role"
  value       = aws_iam_role.application.name
}

# Load Balancer outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.api.arn
}

# Security Group outputs
output "api_security_group_id" {
  description = "ID of the API security group"
  value       = aws_security_group.api.id
}

output "monitoring_security_group_id" {
  description = "ID of the monitoring security group"
  value       = aws_security_group.monitoring.id
}

# CloudWatch outputs
output "cloudwatch_log_group_application" {
  description = "Name of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "cloudwatch_log_group_nginx" {
  description = "Name of the NGINX CloudWatch log group"
  value       = aws_cloudwatch_log_group.nginx.name
}

output "sns_topic_alerts_arn" {
  description = "ARN of the alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

# Environment configuration outputs
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Connection strings and configuration (for application deployment)
output "database_url" {
  description = "Database connection URL template"
  value       = "postgresql://${var.db_username}:PASSWORD@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

output "redis_url" {
  description = "Redis connection URL template"
  value       = "redis://AUTH_TOKEN@${aws_elasticache_replication_group.main.configuration_endpoint_address}:${aws_elasticache_replication_group.main.port}"
  sensitive   = true
}

# Application configuration template
output "application_config" {
  description = "Application environment configuration template"
  value = {
    NODE_ENV = var.environment
    
    # Database
    DATABASE_URL = "postgresql://${var.db_username}:PASSWORD@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
    
    # Redis
    REDIS_URL = "redis://AUTH_TOKEN@${aws_elasticache_replication_group.main.configuration_endpoint_address}:${aws_elasticache_replication_group.main.port}"
    
    # AWS Services
    AWS_REGION = var.aws_region
    S3_DOCUMENTS_BUCKET = aws_s3_bucket.documents.bucket
    S3_BACKUPS_BUCKET = aws_s3_bucket.backups.bucket
    
    # SQS Queues
    SQS_DOCUMENT_PROCESSING_QUEUE_URL = aws_sqs_queue.document_processing.url
    SQS_NOTIFICATIONS_QUEUE_URL = aws_sqs_queue.notifications.url
    SQS_REPORT_GENERATION_QUEUE_URL = aws_sqs_queue.report_generation.url
    
    # Secrets Manager
    SECRETS_DATABASE_ARN = aws_secretsmanager_secret.database.arn
    SECRETS_REDIS_ARN = aws_secretsmanager_secret.redis.arn
    SECRETS_JWT_ARN = aws_secretsmanager_secret.jwt.arn
    
    # Logging
    CLOUDWATCH_LOG_GROUP = aws_cloudwatch_log_group.application.name
    
    # Monitoring
    PROMETHEUS_ENABLED = "true"
    
    # Application
    PORT = "3000"
    LOG_LEVEL = var.environment == "production" ? "info" : "debug"
    LOG_FORMAT = "json"
  }
  sensitive = true
}

# Infrastructure summary
output "infrastructure_summary" {
  description = "Summary of created infrastructure"
  value = {
    vpc = {
      id = module.vpc.vpc_id
      cidr = module.vpc.vpc_cidr_block
      availability_zones = local.azs
    }
    
    database = {
      endpoint = aws_db_instance.main.endpoint
      instance_class = aws_db_instance.main.instance_class
      engine_version = aws_db_instance.main.engine_version
      multi_az = aws_db_instance.main.multi_az
    }
    
    redis = {
      endpoint = aws_elasticache_replication_group.main.configuration_endpoint_address
      node_type = aws_elasticache_replication_group.main.node_type
      num_cache_clusters = aws_elasticache_replication_group.main.num_cache_clusters
    }
    
    load_balancer = {
      dns_name = aws_lb.main.dns_name
      scheme = aws_lb.main.scheme
      type = aws_lb.main.load_balancer_type
    }
    
    storage = {
      documents_bucket = aws_s3_bucket.documents.bucket
      backups_bucket = aws_s3_bucket.backups.bucket
    }
    
    queues = {
      document_processing = aws_sqs_queue.document_processing.name
      notifications = aws_sqs_queue.notifications.name
      report_generation = aws_sqs_queue.report_generation.name
    }
  }
}

# DNS and SSL information
output "dns_configuration" {
  description = "DNS configuration information"
  value = {
    alb_dns_name = aws_lb.main.dns_name
    alb_zone_id = aws_lb.main.zone_id
    # Add Route53 and certificate information when implemented
  }
}

# Cost estimation tags
output "cost_tags" {
  description = "Tags for cost tracking and optimization"
  value = local.common_tags
}