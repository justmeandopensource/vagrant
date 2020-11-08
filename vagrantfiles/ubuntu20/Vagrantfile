# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  config.vm.provision "shell", path: "bootstrap.sh"

  NodeCount = 1

  (1..NodeCount).each do |i|
    config.vm.define "ubuntuvm0#{i}" do |node|
      node.vm.box = "bento/ubuntu-20.04"
      node.vm.hostname = "ubuntuvm0#{i}.example.com"
      node.vm.network "private_network", ip: "172.16.16.10#{i}"
      node.vm.provider "virtualbox" do |v|
        v.name = "ubuntuvm0#{i}"
        v.memory = 2048
        v.cpus = 1
      end
    end
  end

end
