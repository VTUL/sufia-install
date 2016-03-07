# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  # Providers
  config.vm.provider :virtualbox do |vb, override|
    override.vm.network :private_network, ip: "192.168.0.2"
    # Customize the amount of memory on the VM:
    vb.memory = "4096"
    override.vm.provision :shell, path: "install_sufia.sh", args: "vagrant"
  end

  config.vm.provider :aws do |aws, override|
    keypair = ENV['KEYPAIR_NAME']
    keypath = ENV['KEYPAIR_PATH']
    override.vm.synced_folder '.', '/vagrant', :disabled => true
    override.vm.box = "dummy"
    override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    aws.access_key_id = ENV['AWS_ACCESS_KEY']
    aws.secret_access_key = ENV['AWS_SECRET_KEY']
    aws.keypair_name = keypair
    aws.ami = "ami-fce3c696" # Ubuntu Trusty LTS
    aws.region = "us-east-1"
    aws.instance_type = "t2.large"
    aws.security_groups = ["programming_task"]
    #aws.associate_public_ip = true
    override.ssh.username = "ubuntu"
    override.ssh.private_key_path = "#{keypath}/#{keypair}"
    aws.tags = {
      'Name' => "SE Test #{keypair}"
    }
    override.vm.provision "shell", path: "install_sufia.sh", args: "ubuntu"
  end
end
