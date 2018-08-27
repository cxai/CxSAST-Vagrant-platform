# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "alexivkin/windows_2016"
  config.vm.box_check_update = false # faster startup if no network connection

  #config.vm.network "forwarded_port", guest: 80, host: 8080
  #config.vm.network "forwarded_port", guest: 443, host: 8443
  #config.vm.network "forwarded_port", guest: 1433, host: 8433 # MSSQL port for managing the DB with external tools

  config.vm.network "private_network", ip: "192.168.50.5" # to simplify networking, not strictly necessary

  config.vm.synced_folder "~/Shared Folder", "c:/shared folder", type: "virtualbox" # shared content between host and the vm, also used for binding into docker containers

  config.vm.provider "virtualbox" do |vb|
    vb.name = "CxSAST"
    vb.memory = "4096"

    #vb.linked_clone = true # link to the vmbox, dont clone. This is a transient box - it'll revert back to the original image when stopped

    vb.customize ["modifyvm", :id, "--vram", 128]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vb.customize ["modifyvm", :id, "--accelerate3d", "on", "--accelerate2dvideo", "on"]
    vb.customize ["modifyvm", :id, "--audio", "pulse", "--audiocontroller", "hda", "--audioout", "on", "--audioin", "on"]   # YMMV

    #vb.customize ["setextradata", "global", "GUI/SuppressMessages", "all" ]
  end

  config.vm.provision "shell", path: "provision-wintools.ps1", privileged: false # privileged: false required for Windows Server 2016 Build 14393.rs1_release.170917-1700
  config.vm.provision "shell", path: "provision-cxsast.ps1", privileged: false
  config.vm.provision "shell", path: "provision-environment.ps1", privileged: false

end
