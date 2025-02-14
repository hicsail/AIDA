# Fargate Task Definition
resource "aws_ecs_task_definition" "rag_task" {
  family                   = "rag-task"
  cpu                      = "4096" # Adjust CPU as needed
  memory                   = "8192" # Adjust memory as needed
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = "rag"
      image = "ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest"
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "POSTGRES_DB"
          value = "rag"
        },
        {
          name  = "POSTGRES_USER"
          value = "aida"
        },
        {
          name  = "POSTGRES_PASSWORD"
          value = var.database_password
        },
        {
          name  = "DB_HOST",
          value = var.database_host
        },
        {
          name  = "DB_PORT",
          value = "5432"
        },
        {
          name = "EMBEDDINGS_PROVIDER",
          value = "bedrock"
        },
        {
          name = "EMBEDDINGS_MODEL",
          value = "amazon.titan-embed-text-v2:0"
        },
        {
          name = "AWS_ACCESS_KEY_ID",
          value = var.bedrock_access_id
        },
        {
          name = "AWS_SECRET_ACCESS_KEY",
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
resource "aws_security_group" "rag_sg" {
  name        = "rag-sg"
  description = "Allow inbound traffic to Fargate service"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rag_ingress" {
  security_group_id = aws_security_group.rag_sg.id

  cidr_ipv4   = "10.0.0.0/16"
  from_port   = 8000
  ip_protocol = "tcp"
  to_port     = 8000
}

# Fargate Service
resource "aws_ecs_service" "rag_service" {
  name            = "rag-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.rag_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.rag_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.rag_tg.arn
    container_name   = "rag"
    container_port   = 8000
  }

  desired_count = 1
}

# Application Load Balancer
resource "aws_lb_target_group" "rag_tg" {
  name        = "rag-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-499"
  }
}

resource "aws_security_group" "rag_alb_sg" {
  name        = "rag-alb-sg"
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

resource "aws_lb" "rag_alb" {
  name               = "rag-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.rag_alb_sg.id]
  subnets            = var.private_subnet_ids
}

# ALB Listener
resource "aws_lb_listener" "rag_http" {
  load_balancer_arn = aws_lb.rag_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rag_tg.arn
  }
}
