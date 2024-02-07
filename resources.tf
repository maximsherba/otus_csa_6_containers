locals {
  dkr_img_src_path = "${path.module}"
}

resource "aws_ecr_repository" "my_repo" {
  name                 = "test_repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "default_policy" {
  repository = aws_ecr_repository.my_repo.name
	

	  policy = <<EOF
	{
	    "rules": [
	        {
	            "rulePriority": 1,
	            "description": "Keep only the last 10 untagged images.",
	            "selection": {
	                "tagStatus": "untagged",
	                "countType": "imageCountMoreThan",
	                "countNumber": 10
	            },
	            "action": {
	                "type": "expire"
	            }
	        }
	    ]
	}
	EOF
}

data "aws_caller_identity" "this" {}
data "aws_ecr_authorization_token" "this" {}
data "aws_region" "this" {}
locals { ecr_address = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.this.account_id, data.aws_region.this.name) }

output "current_account_id" {
  value = data.aws_caller_identity.this.account_id
}

output "repository_url" {
  value = aws_ecr_repository.my_repo.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.my_repo.name
}

output "dkr_img_src_path" {
  value = path.module
}


resource "null_resource" "docker_packaging" {
	
	  provisioner "local-exec" {
	    command = <<EOF
			aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin ${data.aws_caller_identity.this.account_id}.dkr.ecr.eu-west-3.amazonaws.com	
	        docker build -t ${aws_ecr_repository.my_repo.name}:latest -f ./Dockerfile . 
 			docker tag ${aws_ecr_repository.my_repo.name}:latest ${aws_ecr_repository.my_repo.repository_url}:latest		
            docker push ${aws_ecr_repository.my_repo.repository_url}:latest
	    EOF
	  }

	  triggers = {
	    "run_at" = timestamp()
	  }
}


provider "docker" {
 registry_auth {
  address  = local.ecr_address
  password = data.aws_ecr_authorization_token.this.password
  username = data.aws_ecr_authorization_token.this.user_name
 }
}

resource "docker_image" "this" {
 #name = format("%v:%v", aws_ecr_repository.my_repo.repository_url, formatdate("YYYY-MM-DD'T'hh-mm-ss", timestamp()))
 name = format("%v:%v", aws_ecr_repository.my_repo.repository_url, "tag2")

 build { context = "images/." } # Path to our local Dockerfile
}

# * Push our container image to our ECR.
resource "docker_registry_image" "this" {
 keep_remotely = true # Do not delete old images when a new image is pushed
 name = resource.docker_image.this.name
}
