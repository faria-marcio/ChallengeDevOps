# LB Security Group
resource "aws_security_group" "lb_main" {
  name   = "${var.project_name}-lb-access"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block_all]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.cidr_block_all]
  }

  tags = {
    Name = "${var.project_name}-lb-access"
  }
}

# EC2 Security Group
resource "aws_security_group" "ec2_main" {
  name        = "${var.project_name}-ec2-access"
  description = "Manage access to EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block_all]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.subnet_public_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.cidr_block_all]
  }

  tags = {
    Name = "${var.project_name}-ec2-access"
  }
}

# Private Key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key-pair"
  public_key = tls_private_key.main.public_key_openssh
}

# Local File
resource "local_file" "main" {
  content  = tls_private_key.main.private_key_pem
  filename = "${aws_key_pair.main.key_name}.pem"
}

# Instance Private
resource "aws_instance" "private" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.subnet_private_id[0]
  vpc_security_group_ids = [aws_security_group.ec2_main.id]
  user_data              = <<-EOF
  #!/bin/bash
  sudo apt update && sudo apt upgrade
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt install php7.4
  sudo apt-get install -y libapache2-mod-php7.4 git

  sudo git clone https://github.com/DNXLabs/ChallengeDevOps.git /var/www/lavarel
  sudo chown -R ubuntu:ubuntu /var/www/lavarel
  sudo apt install -y php7.4-{cli,common,curl,zip,gd,mysql,xml,mbstring,json,intl}
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/bin/composer
  chmod +x /usr/bin/composer
  cd /var/www/lavarel
  composer install
  sudo cp .env.example .env
  sudo php artisan key:generate
  sudo php artisan jwt:generate

  EOF

  #CONTAINER
  # user_data              = <<-EOF
  # #!/bin/bash
  # sudo apt-get update
  # sudo apt-get install -y ca-certificates curl gnupg lsb-release
  # sudo mkdir -m 0755 -p /etc/apt/keyrings
  # curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  # echo \
  # "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  # $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  # sudo apt-get update
  # sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
  # sudo apt-get install -y awscli
  # EOF

  tags = {
    Name = "${var.project_name}-ec2-private"
  }
}

# Instance Public
resource "aws_instance" "public" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true
  subnet_id                   = var.subnet_public_id[0]
  vpc_security_group_ids      = [aws_security_group.ec2_main.id]
  user_data                   = <<-EOF
  #!/bin/bash
  sudo apt update && sudo apt upgrade
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt install php7.4
  sudo apt-get install -y libapache2-mod-php7.4 git

  sudo git clone https://github.com/DNXLabs/ChallengeDevOps.git /var/www/lavarel
  sudo chown -R ubuntu:ubuntu /var/www/lavarel
  sudo apt install -y php7.4-{cli,common,curl,zip,gd,mysql,xml,mbstring,json,intl}
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/bin/composer
  chmod +x /usr/bin/composer
  cd /var/www/lavarel
  composer install
  sudo cp .env.example .env
  sudo php artisan key:generate
  sudo php artisan jwt:generate

  EOF

  #DON'T FORGET TO UPDATE .env file

  # SCRIPTS TO RUN IN THE SERVER
  # sudo nano /etc/apache2/sites-available/laravel.conf

  # # with this settin:
  # <VirtualHost *:80>

  #   ServerAdmin marciodefaria@gmail.com
  #   ServerName dnx-devops-challenge-dev-lb-919966185.ap-southeast-2.elb.amazonaws.com
  #   DocumentRoot /var/www/lavarel/public

  #   <Directory /var/www/lavarel/public>
  #      Options +FollowSymlinks
  #      AllowOverride All
  #      Require all granted
  #   </Directory>

  #   ErrorLog ${APACHE_LOG_DIR}/error.log
  #   CustomLog ${APACHE_LOG_DIR}/access.log combined

  # </VirtualHost>

  # sudo a2enmod rewrite
  # sudo a2ensite laravel.conf
  # sudo service apache2 restart
  # cd /var/www/lavarel
  # chmod -R guo+w storage

  tags = {
    Name = "${var.project_name}-ec2-public"
  }
}

# Load Balancer
resource "aws_alb" "main" {
  name               = "${var.project_name}-lb"
  load_balancer_type = "application"
  subnets            = var.subnet_public_id
  security_groups    = [aws_security_group.lb_main.id]
  tags = {
    Name = "${var.project_name}-lb"
  }
}

# Load Balancer - Listener
resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}

# Load Balancer - Target Group
resource "aws_alb_target_group" "main" {
  name        = "${var.project_name}-lb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200-399"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_instance.private
  ]
}

# Load Balancer - Target Group Attachment
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_alb_target_group.main.arn
  target_id        = aws_instance.private.id
  port             = 80
}

# # EFS
# resource "aws_efs_file_system" "main" {
#   creation_token   = var.project_name
#   performance_mode = "generalPurpose"
#   throughput_mode  = "bursting"
#   encrypted        = true

#   tags = {
#     Name = "${var.efs_name}"
#   }
# }

# # EFS Mount
# resource "aws_efs_mount_target" "main" {
#   count           = length(var.subnet_private_id)
#   file_system_id  = aws_efs_file_system.main.id
#   subnet_id       = element(var.subnet_private_id, count.index)
#   security_groups = ["${aws_security_group.efs.id}"]
# }

# # EFS Security Group 
# resource "aws_security_group" "efs" {
#   name        = "${var.project_name}-EFS-Access"
#   description = "Manage access to EFS"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "Access to EFS"
#     from_port       = 2049
#     to_port         = 2049
#     protocol        = "tcp"
#     security_groups = [var.sg_ecs_id]
#     cidr_blocks     = var.subnet_private_cidr
#   }

#   egress {
#     description     = "Access to EFS"
#     from_port       = 2049
#     to_port         = 2049
#     protocol        = "tcp"
#     security_groups = [var.sg_ecs_id]
#     cidr_blocks     = var.subnet_private_cidr
#   }

#   tags = {
#     Name = "${var.project_name}-EFS-Access"
#   }
# }

# # Launch Configuration
# resource "aws_launch_configuration" "main" {
#   name_prefix                 = "${var.project_name}-lc"
#   image_id                    = var.image_id
#   instance_type               = var.instance_type
#   associate_public_ip_address = true
#   security_groups             = ["${aws_security_group.ec2_main.id}"]
#   iam_instance_profile        = aws_iam_instance_profile.ec2.arn
#   user_data                   = <<EOF
#                   #!/bin/bash
#                   echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
#                   mkdir -p /mnt/efs
#                   mount -t efs ${var.efs_id}:/ /mnt/efs
#                 EOF

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # Auto Scaling Group
# resource "aws_autoscaling_group" "main" {
#   name                      = "${var.project_name}-asg"
#   depends_on                = [aws_launch_configuration.main]
#   vpc_zone_identifier       = var.subnet_private_id
#   min_size                  = 2
#   max_size                  = 4
#   desired_capacity          = 2
#   launch_configuration      = aws_launch_configuration.main.name
#   target_group_arns         = [var.lb_tg_arn]
#   health_check_type         = "EC2"
#   health_check_grace_period = 0
#   default_cooldown          = 300
#   termination_policies      = ["OldestInstance"]
#   tag {
#     key                 = "Name"
#     value               = "${var.project_name}-ec2"
#     propagate_at_launch = true
#   }
# }

# # Auto Scaling Policy
# resource "aws_autoscaling_policy" "main" {
#   name                      = "${var.project_name}-asg-policy"
#   policy_type               = "TargetTrackingScaling"
#   estimated_instance_warmup = "90"
#   adjustment_type           = "ChangeInCapacity"
#   autoscaling_group_name    = aws_autoscaling_group.main.name

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }

#     target_value = 40
#   }
# }

# # EC2 Instance Role
# resource "aws_iam_role" "ec2" {
#   name = "${var.project_name}-ec2"
#   assume_role_policy = <<EOF
#   {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
#   }
#   EOF
# }

# # EC2 Instance Profile
# resource "aws_iam_instance_profile" "ec2" {
#   name = "${var.project_name}-ec2"
#   role = aws_iam_role.ec2.name
# }

# # EC2 Instance ARNs
# resource "aws_iam_role_policy_attachment" "ec2" {
#   role       = aws_iam_role.ec2.name
#   count      = length(var.iam_policy_arn_ec2)
#   policy_arn = var.iam_policy_arn_ec2[count.index]
# }
