#Get Ubuntu AMI ID using SSM Parameter endpoint in us-east-2
data "aws_ssm_parameter" "ubuntuAmi" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # verify available version
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-airflow-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}

resource "aws_iam_role_policy_attachment" "s3-fullAccess" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2-fullAccess" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "e2_airflow_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2-ubuntu-web-server" {
  ami                         = data.aws_ssm_parameter.ubuntuAmi.value
  instance_type               = "m7i-flex.large" # verify available type
  associate_public_ip_address = true
  vpc_security_group_ids      = ["_"]  # enter your security group
  subnet_id                   = "_"  # enter your subnet
  key_name                    = "_" # enter only the name of the .pem file
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  user_data = file("userdata.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

}

resource "null_resource" "sleep_example" {
  depends_on = [aws_instance.ec2-ubuntu-web-server]

  provisioner "remote-exec" {
    inline = [
      "echo 'Sleeping for 30 seconds...'",
      "sleep 30",  # Sleep for 30 seconds
      "echo 'Sleep completed!'"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_") # enter file name
    }
  }
}

resource "null_resource" "install_docker" {
  depends_on = [aws_instance.ec2-ubuntu-web-server, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "sudo apt update",
        "sudo apt upgrade -y",
        "sudo apt install -y ca-certificates curl",
        "sudo install -m 0755 -d /etc/apt/keyrings",
        "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
        "sudo chmod a+r /etc/apt/keyrings/docker.asc"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./docker.sources"        # Local path of docker.sources
    destination = "/tmp/docker.sources"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"   # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -m 0644 /tmp/docker.sources /etc/apt/sources.list.d/docker.sources", 
      "echo 'Esperando a que APT libere los bloqueos...'",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'APT ocupado. Esperando 5 segundos...'; sleep 5; done", 
      "sudo apt update",
      "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }
}

resource "null_resource" "before_begin_airflow" {
  depends_on = [null_resource.install_docker]

  provisioner "remote-exec" {
    inline = [
        "sudo mkdir -p /airflow-project",
        "sudo mkdir -p /airflow-project/config",
        "sudo mkdir -p /airflow-project/dags",
        "sudo mkdir -p /airflow-project/logs",
        "sudo mkdir -p /airflow-project/plugins"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./docker-compose.yaml"        # Local path of docker-compose.yaml
    destination = "/tmp/docker-compose.yaml"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./.env"        # Local path of .env
    destination = "/tmp/.env"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./Dockerfile"        # Local path of Dockerfile
    destination = "/tmp/Dockerfile"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/docker-compose.yaml /airflow-project/docker-compose.yaml",  
      "sudo mv /tmp/.env /airflow-project/.env",
      "sudo mv /tmp/Dockerfile /airflow-project/Dockerfile"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "aws_s3_bucket" "datalake" {
  # bucket´s name
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "website_bucket_block" {
  bucket = aws_s3_bucket.datalake.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.datalake.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = fileset("dist", "**")

  bucket = aws_s3_bucket.datalake.id
  key    = each.value
  source = "dist/${each.value}"
  etag   = filemd5("dist/${each.value}")
  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
    },
    regex("[^.]+$", each.value),
    "binary/octet-stream"
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "my_bucket_lifecycle" {

  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    transition {
      days          = 1
      storage_class = "STANDARD_IA"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "datalake_policy" {
  bucket = aws_s3_bucket.datalake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.datalake.arn}/*"
      }
    ]
  })
  
}

resource "null_resource" "first_dag" {
  depends_on = [null_resource.before_begin_airflow]

  provisioner "file" {
    source      = "./dags/first_dag.py"   # Local path of first dag
    destination = "/tmp/first_dag.py"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/first_dag.py /airflow-project/dags/first_dag.py"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "second_dag" {
  depends_on = [null_resource.before_begin_airflow]

  provisioner "file" {
    source      = "./dags/api_etl.py"   # Local path of function python
    destination = "/tmp/api_etl.py"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./dags/x_dag.py"   # Local path of second dag
    destination = "/tmp/x_dag.py"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/api_etl.py /airflow-project/dags/api_etl.py",
      "sudo mv /tmp/x_dag.py /airflow-project/dags/x_dag.py"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-web-server.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}




