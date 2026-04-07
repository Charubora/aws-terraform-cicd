# main.tf

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    Type        = "Public"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-private-subnet"
    Environment = var.environment
    Type        = "Private"
  }
}

# Route Table - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group - EC2
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

# IAM Role for EC2 - S3 read access (least privilege)
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ec2_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance - t2.micro
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

 user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
service docker start
usermod -a -G docker ubuntu

cat > /app.py << 'PYEOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    html = """<!DOCTYPE html>
<html>
<head>
    <title>Charu Bora - DevOps Portfolio</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 60px auto; padding: 0 20px; background: #f5f5f5; }
        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        h1 { color: #1a1a1a; margin-bottom: 4px; }
        .subtitle { color: #666; margin-bottom: 30px; }
        .badge { display: inline-block; background: #e8f4fd; color: #1565c0; padding: 4px 12px; border-radius: 20px; font-size: 13px; margin: 4px; }
        .section { margin-top: 24px; }
        .section h3 { color: #333; border-bottom: 1px solid #eee; padding-bottom: 8px; }
        .status { color: #2e7d32; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Charu Bora</h1>
        <p class="subtitle">DevOps and Cloud Engineer</p>
        <p><span class="status">&#x2714; Live</span> - Deployed via Terraform and GitHub Actions CI/CD</p>
        <div class="section">
            <h3>Stack</h3>
            <span class="badge">AWS EC2</span>
            <span class="badge">VPC</span>
            <span class="badge">S3</span>
            <span class="badge">IAM</span>
            <span class="badge">Terraform</span>
            <span class="badge">GitHub Actions</span>
            <span class="badge">Docker</span>
            <span class="badge">Python Flask</span>
        </div>
        <div class="section">
            <h3>Architecture</h3>
            <p>Multi-tier AWS infrastructure with public/private subnets, EC2 running Dockerized Flask app, S3 remote Terraform state with DynamoDB locking, and automated CI/CD with production approval gate.</p>
        </div>
    </div>
</body>
</html>"""
    return html

@app.route('/health')
def health():
    return {'status': 'healthy', 'environment': 'dev'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYEOF

docker run -d -p 80:5000 \
  -v /app.py:/app.py \
  --name flask-app \
  python:3.9-slim \
  bash -c "pip install flask && python /app.py"
EOF
)

  tags = {
    Name        = "${var.project_name}-web-server"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket - app assets
resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.project_name}-app-bucket-${var.environment}"

  tags = {
    Name        = "${var.project_name}-app-bucket"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
