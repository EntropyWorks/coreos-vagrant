# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

Vagrant.require_version ">= 1.6.0"

CONFIG = File.join(File.dirname(__FILE__), "config.rb")

# Config files genereated when after first run
NODE_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data.node.yaml")
MASTER_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data.master.yaml")

# Defaults for config options defined in CONFIG
$num_instances = 1 
$master_instances = 1 

# Used to fetch a new discovery token for a cluster of size $master_instances
$new_discovery_url = "https://discovery.etcd.io/new?size=#{$master_instances}"

# Setup your network
$ipv4_ip_base="172.17.8"
$master_ip_address = $ipv4_ip_base + '.' + '11'

$instance_name_prefix = "core"
$master_name_prefix = "master"


$update_channel = "alpha"
$enable_serial_logging = false
$share_home = false
$vm_gui = false
$vm_memory = 1024
$vm_cpus = 1
$shared_folders = {}
$forwarded_ports = {}

$kubernetes_version = "0.13.2"

# Attempt to apply the deprecated environment variables 
# to override config.rb
if ENV["MASTER_INSTANCES"].to_i > 0 && ENV["MASTER_INSTANCES"]
  $master_instances = ENV["MASTER_INSTANCES"].to_i
end

if ENV["NUM_INSTANCES"].to_i > 0 && ENV["NUM_INSTANCES"]
  $num_instances = ENV["NUM_INSTANCES"].to_i
end

if ENV["IPV4_IP_BASE"].to_i > 0 && ENV["IPV4_IP_BASE"]
  $pv4_ip_base = ENV["IPV4_IP_BASE"].to_i
end

# Read the config.rb if it exists 
if File.exist?(CONFIG)
  require CONFIG
end

# Use old vb_xxx config variables when set
def vm_gui
  $vb_gui.nil? ? $vm_gui : $vb_gui
end

def vm_memory
  $vb_memory.nil? ? $vm_memory : $vb_memory
end

def vm_cpus
  $vb_cpus.nil? ? $vm_cpus : $vb_cpus
end



if File.exists?('user-data.master') && ARGV[0].eql?('up')
    if File.exists?('user-data.master.yaml')
        puts "Already have user-data.master.yaml"
    else
        require 'open-uri'
        token = open("#{$new_discovery_url}").read
        puts token
        puts $master_ip_address
        file_names = ['user-data.master', 'user-data.node']

        file_names.each do |file_name|
            text_1 = File.read(file_name)
            i = 1
            new_contents_1 = text_1.gsub(/__MASTER_PRIVATE_IP__/, $master_ip_address ).gsub(/__DISCOVERY_URL__/, token ).gsub(/__RELEASE__/, $kubernetes_version )
            File.open(file_name + '.yaml', "w") {|file| file.puts new_contents_1 }
        end
    end
end

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  config.vm.box = "coreos-%s" % $update_channel
  config.vm.box_version = ">= 308.0.1"
  config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % $update_channel

  ["openstack"].each do |openstack|
    config.ssh.username = 'core'
    config.vm.provider openstack do |os, override|
        os.vm.box = "openstack"
        os.vm.username = "#{ENV['OS_USERNAME']}"
        os.vm.api_key  = "#{ENV['OS_PASSWORD']}" 
        os.vm.flavor   = /standard.large/
        os.vm.image    = /CoreOS 618.0.0/
        os.vm.endpoint = "#{ENV['OS_AUTH_URL']}/tokens"  
        os.vm.keypair_name = "#{ENV['OS_KEYPAIR_NAME']}"
        os.vm.ssh_username = "core"
        os.vm.public_network_name = "Ext-Net"
        os.vm.networks = %w(wtf-01)
        os.vm.tenant = "#{ENV['OS_TENANT_NAME']}"
        os.vm.region = "#{ENV['OS_REGION_NAME']}"
    end
  end

  ["vmware_fusion", "vmware_workstation"].each do |vmware|
    config.vm.provider vmware do |v, override|
      v.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json" % $update_channel
    end
  end


#  config.vm.provider :virtualbox do |v|
#    # On VirtualBox, we don't have guest additions or a functional vboxsf
#    # in CoreOS, so tell Vagrant that so it can be smarter.
#    v.check_guest_additions = false
#  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end
  ##### Setup the master first
  (1..$master_instances).each do |i|
    config.vm.define vm_name = "%s-%02d" % [$master_name_prefix, i] do |config|
      config.vm.hostname = vm_name

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), "log")
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
        FileUtils.touch(serialFile)

        ["vmware_fusion", "vmware_workstation"].each do |vmware|
          config.vm.provider vmware do |v, override|
            v.vmx["serial0.present"] = "TRUE"
            v.vmx["serial0.fileType"] = "file"
            v.vmx["serial0.fileName"] = serialFile
            v.vmx["serial0.tryNoRxLoss"] = "FALSE"
          end
        end

          ["openstack"].each do |openstack|
            onfig.ssh.username = 'core'
            config.vm.provider openstack do |os, override|
                os.vm.username = "#{ENV['OS_USERNAME']}"
                os.vm.api_key  = "#{ENV['OS_PASSWORD']}" 
                os.vm.flavor   = /standard.large/
                os.vm.image    = /CoreOS 618.0.0/
                os.vm.endpoint = "#{ENV['OS_AUTH_URL']}/tokens"  
                os.vm.keypair_name = "#{ENV['OS_KEYPAIR_NAME']}"
                os.vm.ssh_username = "core"
                os.vm.public_network_name = "Ext-Net"
                os.vm.networks = %w(wtf-01)
                os.vm.tenant = "#{ENV['OS_TENANT_NAME']}"
                os.vm.region = "#{ENV['OS_REGION_NAME']}"
            end
          end

        config.vm.provider :virtualbox do |vb, override|
          vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
          vb.customize ["modifyvm", :id, "--uartmode1", serialFile]
        end
      end
      # So I can connect to the haproxy
      config.vm.network "forwarded_port", guest: 8000, host: 80, auto_correct: true
      config.vm.network "forwarded_port", guest: 3306, host: 33006, auto_correct: true
      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end
      if $expose_etcd_tcp
        config.vm.network "forwarded_port", guest: 4001, host: ($expose_etcd_tcp + i - 1), auto_correct: true
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v|
          v.gui = vm_gui
          v.vmx['memsize'] = vm_memory
          v.vmx['numvcpus'] = vm_cpus
        end
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = vm_memory
        vb.cpus = vm_cpus
      end

      ip = $ipv4_ip_base + '.' + "#{i+10}"
      config.vm.network :private_network, ip: ip

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      $shared_folders.each_with_index do |(host_folder, guest_folder), index|
        config.vm.synced_folder host_folder.to_s, guest_folder.to_s, id: "core-share%02d" % index, nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if $share_home
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      end

      if File.exist?(MASTER_CONFIG_PATH)
        config.vm.provision :file, :source => "#{MASTER_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end

    end
  end
  (1..$num_instances).each do |i|
    config.vm.define vm_name = "%s-%02d" % [$instance_name_prefix, i] do |config|
      config.vm.hostname = vm_name

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), "log")
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
        FileUtils.touch(serialFile)

        ["vmware_fusion", "vmware_workstation"].each do |vmware|
          config.vm.provider vmware do |v, override|
            v.vmx["serial0.present"] = "TRUE"
            v.vmx["serial0.fileType"] = "file"
            v.vmx["serial0.fileName"] = serialFile
            v.vmx["serial0.tryNoRxLoss"] = "FALSE"
          end
        end

        config.vm.provider :virtualbox do |vb, override|
          vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
          vb.customize ["modifyvm", :id, "--uartmode1", serialFile]
        end
      end
          ["openstack"].each do |openstack|
            config.ssh.username = 'core'
            config.vm.provider openstack do |os, override|
                os.vm.box = "openstack"
                os.vm.openstack_auth_url= "#{ENV['OS_AUTH_URL']}/tokens"  
                os.vm.username = "#{ENV['OS_USERNAME']}"
                os.vm.password  = "#{ENV['OS_PASSWORD']}" 
                os.vm.tenant_name = "#{ENV['OS_TENANT_NAME']}"
                os.vm.flavor   = /standard.large/
                os.vm.image    = /CoreOS 618.0.0/
                os.floating_ip_pool  = "Ext-Net"
                os.vm.keypair_name = "#{ENV['OS_KEYPAIR_NAME']}"
                os.vm.ssh_username = "core"
                os.vm.public_network_name = "Ext-Net"
                os.vm.networks = %w(wtf-01)
                os.vm.region = "#{ENV['OS_REGION_NAME']}"
            end
          end

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end
      if $expose_etcd_tcp
        config.vm.network "forwarded_port", guest: 4001, host: ($expose_etcd_tcp + i - 1), auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
	config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v|
          v.gui = vm_gui
          v.vmx['memsize'] = vm_memory
          v.vmx['numvcpus'] = vm_cpus
        end
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = vm_memory
        vb.cpus = vm_cpus
      end

      ip = $ipv4_ip_base + '.' + "#{i+100}"
      config.vm.network :private_network, ip: ip

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      $shared_folders.each_with_index do |(host_folder, guest_folder), index|
        config.vm.synced_folder host_folder.to_s, guest_folder.to_s, id: "core-share%02d" % index, nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if $share_home
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      end

      if File.exist?(NODE_CONFIG_PATH)
        config.vm.provision :file, :source => "#{NODE_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end

    end
  end
end
