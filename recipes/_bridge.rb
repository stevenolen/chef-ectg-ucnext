# adds shib-oauth2-bridge

db_bridge_obj = ChefVault::Item.load("passwords", "bridge")
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
package 'git'

yum_repository 'epel' do
  description 'Extra Packages for Enterprise Linux'
  mirrorlist 'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-6&arch=$basearch'
  gpgkey 'http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6'
  action :create
end

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

shib_oauth2_bridge 'default' do
  db_user 'bridge'
  db_name 'bridge'
  hostname 'ucnext.org'
  db_password db_bridge
  clients [
    {id: 'next', name: 'next', secret: bridge_secrets['next'], redirect_uri: 'https://ucnext.org/auth/oauth2/shibboleth'}
  ]
end
