#
# Cookbook Name:: ectg-ucnext
# Recipe:: default
#
# Copyright (C) 2015 UC Regents
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# require chef-vault
chef_gem 'chef-vault'
require 'chef-vault'

# some basic package deps. only tested on rhel family.
%w(tar java-1.7.0-openjdk git).each do |pkg|
  package pkg
end

# install ES
elasticsearch_user 'elasticsearch'
elasticsearch_install 'elasticsearch' do
  type :tarball
  version '1.7.2'
end
elasticsearch_configure 'elasticsearch'
elasticsearch_service 'elasticsearch'

service 'elasticsearch' do # recipe above does *not* currently start the service
  action :start
end

# install mysql
db_root_obj = ChefVault::Item.load("passwords", "db_root")
db_root = db_root_obj['staging.ucnext.org']
db_next_obj = ChefVault::Item.load("passwords", "next")
db_next = db_next_obj['staging.ucnext.org']
mysql_service 'default' do
  port '3306'
  version '5.6'
  initial_root_password db_root
  action [:create, :start]
end

mysql_connection = {
  :host => '127.0.0.1',
  :port => 3306,
  :username => 'root',
  :password => db_root
}

# set up ucnext db
mysql2_chef_gem 'default'
mysql_database 'next' do
  connection mysql_connection
  action :create
end
mysql_database_user 'next' do
  connection mysql_connection
  password db_next
  database_name 'next'
  action [:create,:grant]
end

# install nginx
node.set['nginx']['default_site_enabled'] = false
node.set['nginx']['install_method'] = 'package'
include_recipe 'nginx::repo'
include_recipe 'nginx'

directory '/etc/ssl/private' do
  recursive true
end

ssl_key_cert = ChefVault::Item.load('ssl', 'staging.ucnext.org') # gets ssl certs from chef-vault
file "/etc/ssl/certs/staging.ucnext.org.crt" do
  owner 'root'
  group 'root'
  mode '0777'
  content ssl_key_cert['cert']
  notifies :reload, 'service[nginx]', :delayed
end
file "/etc/ssl/private/staging.ucnext.org.key" do
  owner 'root'
  group 'root'
  mode '0600'
  content ssl_key_cert['key']
  notifies :reload, 'service[nginx]', :delayed
end

template '/etc/nginx/sites-available/ucnext' do
  source 'ucnext.conf.erb'
  mode '0775'
  action :create
  variables(
    port: 3000,
    fqdn: 'staging.ucnext.org',
    path: '/var/www/' # not used.
  )
  notifies :reload, 'service[nginx]', :delayed
end
nginx_site 'ucnext' do
  action :enable
end

# install ruby with rbenv, npm, git
node.default['rbenv']['rubies'] = ['2.2.3']
include_recipe 'ruby_build'
include_recipe 'ruby_rbenv::system'
include_recipe 'nodejs::npm'
rbenv_global '2.2.3'
rbenv_gem 'bundle'

rails_secrets = ChefVault::Item.load("secrets", "rails_secret_tokens")
# ucnext staging service
ucnext 'staging' do
  revision '40c5223ffa87b6e03c7e31ee90178522d650ca3f'
  port 3000
  secret rails_secrets['staging.ucnext.org']
  deploy_path '/var/next'
  bundler_path '/usr/local/rbenv/shims'
end
