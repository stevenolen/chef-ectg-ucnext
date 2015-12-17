# adds shib-oauth2-bridge
fqdn = node['fqdn']
db_root_obj = ChefVault::Item.load("passwords", "db_root")
db_root = db_root_obj[fqdn]
mysql_connection = {
  :host => '127.0.0.1',
  :port => 3306,
  :username => 'root',
  :password => db_root
}

db_bridge_obj = ChefVault::Item.load('passwords', 'bridge')
db_bridge = db_bridge_obj[fqdn]

mysql_database 'bridge' do
  connection mysql_connection
  action :create
end
mysql_database_user 'bridge' do
  connection mysql_connection
  password db_bridge
  database_name 'bridge'
  action [:create,:grant]
end

include_recipe 'shib-oauth2-bridge::shibd'
include_recipe 'shib-oauth2-bridge::shib-ds'
package 'git'

yum_repository 'remi' do
  description 'Les RPM de Remi - Repository'
  mirrorlist 'http://rpms.famillecollet.com/enterprise/6/remi/mirror'
  gpgkey 'http://rpms.famillecollet.com/RPM-GPG-KEY-remi'
  action :create
end

yum_repository 'remi-php55' do
  description 'Les RPM de Remi PHP55 - Repository'
  mirrorlist 'http://rpms.famillecollet.com/enterprise/6/php55/mirror'
  gpgkey 'http://rpms.famillecollet.com/RPM-GPG-KEY-remi'
  action :create
end

%w(php php-mcrypt php-mysql php-mbstring).each do |pkg|
  package pkg
end

bridge_secrets = ChefVault::Item.load('secrets', 'oauth2')
shib_oauth2_bridge 'default' do
  db_user 'bridge'
  db_name 'bridge'
  hostname 'ucnext.org'
  db_password db_bridge
  clients [
    {id: 'next', name: 'next', secret: bridge_secrets['next'], redirect_uri: 'https://ucnext.org/auth/oauth2/shibboleth'}
  ]
end
