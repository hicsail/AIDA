# LiteLLM Master Key
resource "random_password" "litellm_master_password" {
  length      = 20
  special     = true
  min_special = 0
}

resource "random_password" "litellm_key_password" {
  length      = 20
  special     = true
  min_special = 0
}

resource "aws_secretsmanager_secret" "litellm_secret" {
  name = "litellm-secret"
}

resource "aws_secretsmanager_secret_version" "litellm_secret_value" {
  secret_id = aws_secretsmanager_secret.litellm_secret.id
  secret_string = jsonencode({
    key  = "sk-${random_password.litellm_master_password.result}",
    salt = "sk-${random_password.litellm_key_password.result}"
  })
}

# Fargate Task Definition
resource "aws_ecs_task_definition" "litellm_task" {
  family                   = "litellm-task"
  cpu                      = "4096" # Adjust CPU as needed
  memory                   = "8192" # Adjust memory as needed
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = "litellm"
      image = "ghcr.io/berriai/litellm:main-latest"
      portMappings = [
        {
          containerPort = 4000
          hostPort      = 4000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "LITELLM_MASTER_KEY",
          value = jsondecode(aws_secretsmanager_secret_version.litellm_secret_value.secret_string).key
        },
        {
          name  = "LITELLM_SALT_KEY",
          value = jsondecode(aws_secretsmanager_secret_version.litellm_secret_value.secret_string).salt
        },
        {
          name  = "LITELLM_BEDROCK_ACCESS_ID",
          value = var.bedrock_access_id
        },
        {
          name  = "LITELLM_BEDROCK_ACCESS_SECRET",
          value = var.bedrock_access_secret
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_log_group
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Security Group for Fargate
resource "aws_security_group" "litellm_sg" {
  name        = "litellm-sg"
  description = "Allow inbound traffic to Fargate service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fargate Service
resource "aws_ecs_service" "litellm_service" {
  name            = "litellm-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.litellm_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.litellm_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.litellm_tg.arn
    container_name   = "litellm"
    container_port   = 4000
  }

  desired_count = 1
}

# Application Load Balancer
resource "aws_lb_target_group" "litellm_tg" {
  name        = "litellm-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-399"
  }
}

resource "aws_security_group" "litellm_alb_sg" {
  name        = "litellm-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTP inbound traffic
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }

  # Allow HTTPS inbound traffic
  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "litellm_alb" {
  name               = "litellm-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.litellm_alb_sg.id]
  subnets            = var.public_subnet_ids
}

# ALB Listener
resource "aws_lb_listener" "litellm_http" {
  load_balancer_arn = aws_lb.litellm_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.litellm_tg.arn
  }
}
