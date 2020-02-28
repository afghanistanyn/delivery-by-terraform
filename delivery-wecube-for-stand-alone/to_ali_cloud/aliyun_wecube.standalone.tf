#全局变量
variable "instance_root_password" {
  description = "Warn: to be safety, please setup real password by using os env variable - 'TF_VAR_instance_root_password'"
  default = "WeCube1qazXSW@"
}

variable "mysql_root_password" {
  description = "Warn: to be safety, please setup real password by using os env variable - 'TF_VAR_mysql_root_password'"
  default = "WeCube1qazXSW@"
}

variable "wecube_version" {
  description = "You can override the value by setup os env variable - 'TF_VAR_wecube_version'"
  default = "v2.1.1"
}

#创建VPC
resource "alicloud_vpc" "vpc" {
  name       = "HZ_MGMT"
  cidr_block = "10.128.192.0/19"
}

#创建交换机（子网）- Wecube Platform组件运行的实例
resource "alicloud_vswitch" "switch_app" {
  name              = "HZPB_MGMT_MT_APP"
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "10.128.202.0/25"
  availability_zone = "cn-hangzhou-b"
}

#创建安全组
resource "alicloud_security_group" "sc_group" {
  name        = "SG_WECUBE"
  description = "Wecube Security Group"
  vpc_id      = "${alicloud_vpc.vpc.id}"
}

#创建安全规则入站
resource "alicloud_security_group_rule" "allow_19090_tcp" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "19090"
  priority          = 1
  security_group_id = "${alicloud_security_group.sc_group.id}"
  cidr_ip           = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "allow_22_tcp" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22"
  priority          = 2
  security_group_id = "${alicloud_security_group.sc_group.id}"
  cidr_ip           = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "allow_9000_tcp" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "9000"
  priority          = 3
  security_group_id = "${alicloud_security_group.sc_group.id}"
  cidr_ip           = "0.0.0.0/0"
}

#创建安全规则出站
resource "alicloud_security_group_rule" "allow_all_tcp_out" {
  type              = "egress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.sc_group.id}"
  cidr_ip           = "0.0.0.0/0"
}

#创建WeCube Platform主机
resource "alicloud_instance" "instance_wecube_platform" {
  availability_zone = "cn-hangzhou-b"  
  security_groups   = "${alicloud_security_group.sc_group.*.id}"
  instance_type              = "ecs.g6.xlarge"
  #image_id          = "centos_8_0_x64_20G_alibase_20191225.vhd"
  image_id          = "centos_7_7_x64_20G_alibase_20191225.vhd"
  system_disk_category       = "cloud_efficiency"
  instance_name              = "instance_wecube_platform"
  vswitch_id                 = "${alicloud_vswitch.switch_app.id}"
  private_ip         ="10.128.202.3"
  internet_max_bandwidth_out = 10
  password ="${var.instance_root_password}"

#初始化配置
  connection {
    type     = "ssh"
    user     = "root"
    password = "${var.instance_root_password}"
    host     = "${alicloud_instance.instance_wecube_platform.public_ip}"
  }

  provisioner "local-exec" {
    command = "cp -r ../application application"
  }

  provisioner "file" {
    source      = "../application"
    destination = "/root/application"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/application/wecube/*.sh",
	  "yum install dos2unix -y",
      "dos2unix /root/application/wecube/*",
	  "cd /root/application/wecube",
	  "./install-wecube.sh ${alicloud_instance.instance_wecube_platform.private_ip} ${var.mysql_root_password} ${var.wecube_version}"
    ]
  }

  provisioner "local-exec" {
    command = "rm -rf application"
  }
}

output "wecube_website" {
  value="http://${alicloud_instance.instance_wecube_platform.public_ip}:19090"
}