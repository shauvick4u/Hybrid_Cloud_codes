provider "aws" {
	region = "ap-south-1"
	profile = "LW_profile"
}

resource "aws_security_group" "my_sec_gp" {
  	name        = "Allow_TCP"
  	description = "TCP_inbound_rules"

  	ingress {
    	  description = "TCP"
    	  from_port   = 80
    	  to_port     = 80
    	  protocol    = "tcp"
    	  cidr_blocks = ["0.0.0.0/0"]
  	}

	ingress {
    	  description = "SSH"
    	  from_port   = 22
    	  to_port     = 22
    	  protocol    = "tcp"
    	  cidr_blocks = ["0.0.0.0/0"]
  	}

  	egress {
    	  from_port   = 0
    	  to_port     = 0
    	  protocol    = "-1"
    	  cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "My_new_Security"
  	}
}

resource "aws_instance" "my_instance" {
	depends_on = [
    	aws_security_group.my_sec_gp
  	]

	ami = "ami-0447a12f28fddb066"
 	instance_type = "t2.micro"
	key_name = "second_key_pair"
	security_groups = ["Allow_TCP"]
	tags = {
		Name = "task_1_WEB"
	}

	connection {
    	type     = "ssh"
    	user     = "ec2-user"
    	private_key = file("C:/Users/Shauvick Das/Desktop/Hybrid cloud recordings/keys/second_key_pair.pem")
    	host     = aws_instance.my_instance.public_ip
  	}

	provisioner "remote-exec" {
    	inline = [
      	"sudo yum install git httpd -y",
      	"sudo systemctl restart httpd",
	"sudo systemctl enable httpd"
    	]
  	}     
}

resource "aws_ebs_volume" "my_volume" {
  	availability_zone = aws_instance.my_instance.availability_zone
  	size              = 1

  	tags = {
    	Name = "task_1_SSD"
  	}
}

resource "aws_volume_attachment" "ebs_attach" {
  	device_name = "/dev/sdf"
  	volume_id = "${aws_ebs_volume.my_volume.id}"
  	instance_id = "${aws_instance.my_instance.id}"
	force_detach = true
}  

resource "null_resource" "null_res_1" {
	depends_on = [
    	aws_volume_attachment.ebs_attach,
  	]  
	connection {
    	type     = "ssh"
    	user     = "ec2-user"
    	private_key = file("C:/Users/Shauvick Das/Desktop/Hybrid cloud recordings/keys/second_key_pair.pem")
    	host     = aws_instance.my_instance.public_ip
  	}

	provisioner "remote-exec" {
    	inline = [
	"sudo mkfs.ext4 /dev/xvdf",
      	"sudo mount  /dev/xvdf  /var/www/html",
      	"sudo rm -rf /var/www/html/*",  
      	"sudo git clone https://github.com/shauvick4u/web_html_codes.git /var/www/html/"
    	]
  	}
}  

resource "aws_s3_bucket" "my_bucket" {
  	bucket = "my-terraform-task1-bucket"
  	acl    = "private"
	region = "ap-south-1"

  	tags = {
    	Name        = "My-task_1-bucket"
  	}
}

resource "aws_s3_bucket_object" "my_object" {
	depends_on = [
    	aws_s3_bucket.my_bucket,
  	]
	acl = "public-read"
 	bucket = "my-terraform-task1-bucket"
  	key    = "folder/image.jpg"
  	source = "C:/Users/Shauvick Das/Desktop/terra/image.jpg"
	content_type = "image/jpeg"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
	depends_on = [
    	aws_s3_bucket.my_bucket,
	aws_s3_bucket_object.my_object
  	]
	
  	origin {
    	domain_name = aws_s3_bucket.my_bucket.bucket_regional_domain_name
    	origin_id   = "my_web_ID"

  	}
	enabled = true
	is_ipv6_enabled = true
  	default_root_object = "folder/image.jpg"

  	default_cache_behavior {
    	allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    	cached_methods   = ["GET", "HEAD"]
    	target_origin_id = "my_web_ID"

    	forwarded_values {
      	query_string = false

      		cookies {
        		forward = "none"
      		}
    	}

    	viewer_protocol_policy = "allow-all"
    	min_ttl                = 0
    	default_ttl            = 3600
    	max_ttl                = 86400
  	}
  	restrictions {
    		geo_restriction {
      			restriction_type = "none"
    		}
  	}

  	tags = {
    		Environment = "testing"
  	}

  	viewer_certificate {
    		cloudfront_default_certificate = true
  	}
} 

resource "null_resource" "null_res_2" {
	depends_on = [
    	aws_cloudfront_distribution.s3_distribution,
  	]
	connection {
    	type     = "ssh"
    	user     = "ec2-user"
    	private_key = file("C:/Users/Shauvick Das/Desktop/Hybrid cloud recordings/keys/second_key_pair.pem")
    	host     = aws_instance.my_instance.public_ip
  	}

	provisioner "remote-exec" {
    	inline = [
	"sudo sed -i 's~image.url~http://${aws_cloudfront_distribution.s3_distribution.domain_name}~' /var/www/html/index.html"
	]
  	}
}  

output "Instance_IP_output" {
	value = aws_instance.my_instance.public_ip
} 