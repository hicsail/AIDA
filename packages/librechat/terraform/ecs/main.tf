resource "aws_ecr_repository" "beacon_api" {
  name = "beacon-api"
}

resource "aws_ecr_repository" "beacon_ai" {
  name = "beacon-ai"
}

# Create ECS cluster
resource "aws_ecs_cluster" "beacon-api" {
  name = "beacon-api"
}
# IAM Role for Fargate Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_pull_policy" {
  name = "ecr-pull-policy"
  description = "Policy to allow ECS tasks to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowECRPullAccess",
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
    name = "ecs-task-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "ecs-tasks.amazonaws.com"
            }
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecr_pull_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/beacon-api"
  retention_in_days = 14
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "ecs-cloudwatch-logs-policy"
  description = "Policy to allow ECS tasks to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.ecs_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# Fargate Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "beacon-api-task"
  cpu                      = "1024"   # Adjust CPU as needed
  memory                   = "2048"   # Adjust memory as needed
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "beacon-api"
      image       = "${aws_ecr_repository.beacon_api.repository_url}:main"
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_host
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# Security Group for Fargate
resource "aws_security_group" "fargate_sg" {
  name        = "fargate-sg"
  description = "Allow inbound traffic to Fargate service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
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
resource "aws_ecs_service" "service" {
  name            = "beacon-api-service"
  cluster         = aws_ecs_cluster.beacon-api.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "beacon-api"
    container_port   = 3000
  }

  desired_count = 1
}

# Fargate AI Task Definition
resource "aws_ecs_task_definition" "ai-task" {
  family                   = "beacon-ai-task"
  cpu                      = "1024"   # Adjust CPU as needed
  memory                   = "2048"   # Adjust memory as needed
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "beacon-ai"
      image       = "${aws_ecr_repository.beacon_ai.repository_url}:main"
      environment = [
        {
          name  = "REDIS_HOST"
          value = var.redis_host
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Fargate Service
resource "aws_ecs_service" "ai-service" {
  name            = "beacon-ai-service"
  cluster         = aws_ecs_cluster.beacon-api.id
  task_definition = aws_ecs_task_definition.ai-task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  desired_count = 1
}

# Application Load Balancer
resource "aws_lb_target_group" "tg" {
  name        = "beacon-api-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
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



resource "aws_lb" "alb" {
  name               = "beacon-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}