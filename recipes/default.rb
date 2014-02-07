include_recipe "rbenv"
include_recipe "rbenv::ruby_build"
include_recipe "build-essential"

node.default['passenger']['apache_mpm']  = 'prefork'

case node['platform_family']
when "arch"
  package "apache"
when "rhel"
  package "httpd-devel"
  if node['platform_version'].to_f < 6.0
    package 'curl-devel'
  else
    package 'libcurl-devel'
    package 'openssl-devel'
    package 'zlib-devel'
  end
else
  apache_development_package =  if %w( worker threaded ).include? node['rbenv']['passenger']['apache_mpm']
                                  'apache2-threaded-dev'
                                else
                                  'apache2-prefork-dev'
                                end
  %W( #{apache_development_package} libapr1-dev libcurl4-gnutls-dev ).each do |pkg|
    package pkg do
      action :upgrade
    end
  end
end

# Install required ruby and passenger gem
rbenv_ruby node['rbenv']['passenger']['gem_ruby']
rbenv_gem "passenger" do
  ruby_version node['rbenv']['passenger']['gem_ruby']
  version node['rbenv']['passenger']['version']
end

# Load configuration paths
ruby_block "set module_path" do
  block { PassengerRbenvConfig.set_passenger_config(node) }
end

# Build the apache module
execute "passenger_module" do
  command "#{node[:rbenv][:root_path]}/versions/#{node['rbenv']['passenger']['gem_ruby']}/bin/passenger-install-apache2-module _#{node['rbenv']['passenger']['version']}_ --auto"
  not_if { ::File.exists?(node['rbenv']['passenger']['module_path']) }
end

include_recipe "apache2"

# This is required because the apache_module resource do not create the load file for debian platforms
template "#{node['apache']['dir']}/mods-available/passenger.load" do
  cookbook 'rbenv_passenger'
  source 'passenger.load.erb'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, 'service[apache2]'
end

# Create configuration file
template "#{node['apache']['dir']}/mods-available/passenger.conf" do
  cookbook 'rbenv_passenger'
  source 'passenger.conf.erb'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, 'service[apache2]'
end

execute "a2enmod passenger" do
  command "/usr/sbin/a2enmod passenger"
  notifies :restart, 'service[apache2]'
  not_if do
    ::File.symlink?("#{node['apache']['dir']}/mods-enabled/passenger.load") &&
    (::File.exists?("#{node['apache']['dir']}/mods-available/passenger.conf") ? ::File.symlink?("#{node['apache']['dir']}/mods-enabled/passenger.conf") : true)
  end
end
