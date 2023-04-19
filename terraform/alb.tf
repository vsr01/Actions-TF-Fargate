# -----------------------------------------------------------------------------
# Application Load Balancer (ALB)
#
# Flow you are modeling: Internet -> ALB:80 -> target group -> Fargate task:5000
# Pair this file with ecs.tf (service attachment) and vpc.tf (ALB + task subnets/SGs).
# -----------------------------------------------------------------------------

resource "aws_lb" "app" {
  name_prefix        = "alb-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  # Health checks run against *registered task IPs*. Using /health avoids coupling
  # target health to MySQL availability (see app/app.py). Try switching path to "/"
  # in a lab to see how DB outages affect ALB routing.
  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
