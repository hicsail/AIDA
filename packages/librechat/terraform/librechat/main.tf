# LibreChat JWT Secret
resource "random_password" "librechat_jwt_secret" {
  length      = 20
  special     = false
  min_special = 0
}

# LibreChat JWT Refresh
resource "random_password" "librechat_jwt_refresh" {
  length      = 20
  special     = false
  min_special = 0
}

resource "aws_secretsmanager_secret" "librechat_jwt_secret" {
  name = "librechat-jwt-secret"
}

resource "aws_secretsmanager_secret_version" "librechat_jwt_secret_value" {
  secret_id = aws_secretsmanager_secret.librechat_jwt_secret.id
  secret_string = jsonencode({
    secret  = random_password.librechat_jwt_secret.result,
    refresh = random_password.librechat_jwt_refresh.result
  })
}

# LibreChat Creds Secret
resource "random_id" "librechat_creds_key" {
  byte_length = 32
}

# LibreChat Creds IV
resource "random_id" "librechat_creds_iv" {
  byte_length = 16
}

resource "aws_secretsmanager_secret" "librechat_creds_secret" {
  name = "librechat-creds-secret"
}

resource "aws_secretsmanager_secret_version" "librechat_creds_secret_value" {
  secret_id = aws_secretsmanager_secret.librechat_creds_secret.id
  secret_string = jsonencode({
    key = random_id.librechat_creds_key.hex,
    iv  = random_id.librechat_creds_iv.hex
  })
}

# EFS to store configuration
resource "aws_efs_file_system" "librechat_efs" {
  creation_token = "librechat_efs"
}

resource "aws_security_group" "librechat_efs_sg" {
  name        = "librechat-efs-sg"
  description = "Allow inbound traffic to LibreChat efs"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
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

resource "aws_efs_mount_target" "librechat_mount_target" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.librechat_efs.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.librechat_efs_sg.id]
}

# Fargate Task Definition
resource "aws_ecs_task_definition" "librechat_task" {
  family                   = "librechat-task"
  cpu                      = "4096" # Adjust CPU as needed
  memory                   = "8192" # Adjust memory as needed
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = "librechat"
      image = "ghcr.io/danny-avila/librechat-dev:latest"
      portMappings = [
        {
          containerPort = 3080
          hostPort      = 3080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "HOST",
          value = "0.0.0.0"
        },
        {
          name  = "PORT",
          value = "3080"
        },
        {
          name  = "MONGO_URI",
          value = var.database_url
        },
        {
          name  = "SEARCH",
          value = "false"
        },
        {
          name  = "ALLOW_EMAIL_LOGIN",
          value = "true"
        },
        {
          name  = "ALLOW_REGISTRATION",
          value = "false"
        },
        {
          name  = "ALLOW_SOCIAL_REGISTRATION",
          value = "false"
        },
        {
          name  = "ALLOW_PASSWORD_RESET",
          value = "false"
        },
        {
          name  = "ALLOW_UNVERIFIED_EMAIL_LOGIN",
          value = "true"
        },
        {
          name  = "JWT_SECRET",
          value = "${jsondecode(aws_secretsmanager_secret_version.librechat_jwt_secret_value.secret_string).secret}"
        },
        {
          name  = "JWT_REFRESH_SECRET",
          value = "${jsondecode(aws_secretsmanager_secret_version.librechat_jwt_secret_value.secret_string).refresh}"
        },
        {
          name  = "CREDS_KEY",
          value = "${jsondecode(aws_secretsmanager_secret_version.librechat_creds_secret_value.secret_string).key}"
        },
        {
          name  = "CREDS_IV",
          value = "${jsondecode(aws_secretsmanager_secret_version.librechat_creds_secret_value.secret_string).iv}"
        },
        {
          name  = "SESSION_EXPIRY",
          value = "1000 * 60 * 15"
        },
        {
          name  = "REFRESH_TOKEN_EXPIRY",
          value = "(1000 * 60 * 60 * 24) * 7"
        },
        {
          name  = "APP_TITLE",
          value = "LibreChat BU"
        },
        {
          name  = "HELP_AND_FAQ_URL",
          value = "https://librechat.ai"
        },
        {
          name  = "CONFIG_PATH",
          value = "/efs/librechat.yaml"
        },
        {
          name  = "LITELLM_API_KEY",
          value = var.litellm_key
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
      volume = {
        name = "librechat_config"
        host_path = "/efs"
      }
    }
  ])

  volume {
    name = "librechat_config"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.librechat_efs.id
    }
  }
}

# Security Group for Fargate
resource "aws_security_group" "librechat_sg" {
  name        = "librechat-sg"
  description = "Allow inbound traffic to Fargate service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3080
    to_port     = 3080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Fargate Service
resource "aws_ecs_service" "librechat_service" {
  name            = "librechat-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.librechat_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.librechat_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.librechat_tg.arn
    container_name   = "librechat"
    container_port   = 3080
  }

  desired_count = 1
}

# Application Load Balancer
resource "aws_lb_target_group" "librechat_tg" {
  name        = "librechat-tg"
  port        = 3080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-399"
  }
}

resource "aws_security_group" "librechat_alb_sg" {
  name        = "librechat-alb-sg"
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

resource "aws_lb" "librechat_alb" {
  name               = "librechat-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.librechat_alb_sg.id]
  subnets            = var.public_subnet_ids
}

# ALB Listener
resource "aws_lb_listener" "librechat_http" {
  load_balancer_arn = aws_lb.librechat_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.librechat_tg.arn
  }
}
