#
# Cookbook Name:: neo4j
# Recipe:: default
#
# Copyright 2011, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

require_recipe "java"

neo4j_version=node[:neo4j][:version]||"1.2"
tarball = "neo4j-#{neo4j_version}-unix.tar.gz"
downloaded_tarball = "/tmp/#{tarball}"
installation_dir = "/opt"
exploded_tarball = "#{installation_dir}/neo4j-#{neo4j_version}"
installed_app_dir = "#{installation_dir}/neo4j"
ha_address = node[:neo4j][:ha_address]||node[:ipaddress]

# download remote file
remote_file "#{downloaded_tarball}" do
  source "http://dist.neo4j.org/#{tarball}"
  mode "0644"
end

# unpack the downloaded file
execute "tar" do
 user "root"
 group "root"

 cwd installation_dir
 command "tar zxf #{downloaded_tarball}"
 creates exploded_tarball
 action :run
end

# rename the directory to plain ol' neo4j
execute "mv #{exploded_tarball} #{installed_app_dir}" do
  user "root"
  group "root"

  creates installed_app_dir
end

# create teh data directory 
directory "#{node[:neo4j][:database_location]}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

template "#{installed_app_dir}/conf/neo4j-server.properties" do
  source "neo4j-server.erb"
  mode 0444
  owner "root"
  group "root"
  variables(
    :enable_ha => node[:neo4j][:enable_ha],
    :database_location => node[:neo4j][:database_location],
    :webserver_port => node[:neo4j][:webserver_port]
  )
end


template "#{installed_app_dir}/conf/neo4j.properties" do
  source "neo4j.erb"
  mode 0444
  owner "root"
  group "root"
  variables(
    :enable_ha => node[:neo4j][:enable_ha],
    :ha_server => "#{ha_address}:#{node[:neo4j][:ha_port]}",
    :ha_machine_id => node[:neo4j][:ha_machine_id],
    :zookeeper_port => node[:neo4j][:zookeeper_port],
    :zookeeper_addresses => node[:neo4j][:zookeeper_addresses]
  )
end

# ask Neo4j to install start/stop scripts for itself
execute "./neo4j install" do
  user "root"
  group "root"

  cwd installed_app_dir + "/bin"
  creates "/etc/init.d/neo4j-server"
end

# finally, start the server
execute "./neo4j-server start" do
  user "root"
  group "root"

  cwd "/etc/init.d"
  not_if do
    File.exists?("#{installed_app_dir}/data/neo4j-server.pid")
  end

end

