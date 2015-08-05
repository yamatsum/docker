################
# action :create
################

# default action, default properties
docker_container 'hello-world' do
  command '/hello'
  action :create
end

#############
# action :run
#############

# This command will exit and the container will stop.
docker_container 'busybox_ls' do
  repo 'busybox'
  command 'ls -la /'
  not_if "[ ! -z `docker ps -qaf 'name=busybox_ls$'` ]"
  action :run
end

###############
# port property
###############

# a long running process
docker_container 'an_echo_server' do
  repo 'alpine'
  tag '3.1'
  command 'nc -ll -p 7 -e /bin/cat'
  port '7:7'
  action :run
end

# let docker pick the host port
docker_container 'another_echo_server' do
  repo 'alpine'
  tag '3.1'
  command 'nc -ll -p 7 -e /bin/cat'
  port '7'
  action :run
end

# specify the udp protocol
docker_container 'an_udp_echo_server' do
  repo 'alpine'
  tag '3.1'
  command 'nc -ul -p 7 -e /bin/cat'
  port '5007:7/udp'
  action :run
end

##############
# action :kill
##############

# start a container to be killed
execute 'bill' do
  command 'docker run --name bill -d busybox nc -ll -p 187 -e /bin/cat'
  not_if "[ ! -z `docker ps -qaf 'name=bill$'` ]"
  notifies :run, 'execute[container_marker_bill]', :immediately
  action :run
end

# marker to prevent :run on subsequent converges.
execute 'container_marker_bill' do
  command 'touch /tmp/container_marker_bill'
  action :nothing
end

docker_container 'bill' do
  action :kill
end

##############
# action :stop
##############

# start a container to be stopped
execute 'hammer_time' do
  command 'docker run --name hammer_time -d busybox nc -ll -p 187 -e /bin/cat'
  not_if "[ ! -z `docker ps -qaf 'name=hammer_time$'` ]"
  action :run
end

docker_container 'hammer_time' do
  action :stop
end

###############
# action :pause
###############

# start a container to be paused
execute 'red_light' do
  command 'docker run --name red_light -d busybox nc -ll -p 42 -e /bin/cat'
  not_if "[ ! -z `docker ps -qaf 'name=red_light'` ]"
  action :run
end

docker_container 'red_light' do
  action :pause
end

#################
# action :unpause
#################

# start and pause a container to be unpaused
bash 'green_light' do
  code <<-EOF
  docker run --name green_light -d busybox nc -ll -p 42 -e /bin/cat
  docker pause green_light
  EOF
  not_if "[ ! -z `docker ps -qaf 'name=green_light$'` ]"
  action :run
end

docker_container 'green_light' do
  action :unpause
end

#################
# action :restart
#################

# create and stop a container to be restarted
bash 'quitter' do
  code <<-EOF
  docker run --name quitter -d busybox nc -ll -p 69 -e /bin/cat
  docker kill quitter
  EOF
  not_if "[ ! -z `docker ps -qaf 'name=quitter'` ]"
  action :run
end

docker_container 'quitter' do
  not_if { ::File.exist? '/tmp/container_marker_quitter_restarter' }
  notifies :run, 'execute[container_marker_quitter_restarter]'
  action :restart
end

execute 'container_marker_quitter_restarter' do
  command 'touch /tmp/container_marker_quitter_restarter'
  action :nothing
end

# start a container to be restarted
bash 'restarter' do
  code <<-EOF
  docker run --name restarter -d busybox nc -ll -p 69 -e /bin/cat
  EOF
  not_if "[ ! -z `docker ps -qaf 'name=restarter$'` ]"
  action :run
end

docker_container 'restarter' do
  not_if { ::File.exist? '/tmp/container_marker_restarter_restarter' }
  notifies :run, 'execute[container_marker_restarter_restarter]'
  action :restart
end

execute 'container_marker_restarter_restarter' do
  command 'touch /tmp/container_marker_restarter_restarter'
  action :nothing
end

################
# action :delete
################

# create a container to be deleted
execute 'deleteme' do
  command 'docker run --name deleteme -d busybox nc -ll -p 187 -e /bin/cat'
  not_if "[ ! -z `docker ps -qaf 'name=deleteme'` ]"
  not_if { ::File.exist?('/tmp/container_marker_deleteme') }
  notifies :run, 'execute[container_marker_deleteme]'
  action :run
end

execute 'container_marker_deleteme' do
  command 'touch /tmp/container_marker_deleteme'
  action :nothing
end

docker_container 'deleteme' do
  action :delete
end

##################
# action :redeploy
##################

execute 'redeploy an_echo_server' do
  command 'touch /tmp/container_marker_an_echo_server_redeploy'
  creates '/tmp/container_marker_an_echo_server_redeploy'
  notifies :redeploy, 'docker_container[an_echo_server]'
  action :run
end

#############
# bind mounts
#############

directory '/hostbits' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

file '/hostbits/hello.txt' do
  content 'hello there\n'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

directory '/more-hostbits' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

file '/more-hostbits/hello.txt' do
  content 'hello there\n'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

# Inspect the docker logs with test-kitchen bussers.
docker_container 'bind_mounter' do
  repo 'busybox'
  command 'ls -la /bits /more-bits'
  binds ['/hostbits:/bits', '/more-hostbits:/more-bits']
  not_if "[ ! -z `docker ps -qaf 'name=bind_mounter$'` ]"
  action :run
end

##############
# volumes_from
##############

# build a chef container
directory '/chefbuilder' do
  owner 'root'
  group 'root'
  action :create
end

execute 'copy chef to chefbuilder' do
  command 'tar cf - /opt/chef | tar xf - -C /chefbuilder'
  creates '/chefbuilder/opt'
  action :run
end

file '/chefbuilder/Dockerfile' do
  content <<-EOF
  FROM scratch
  ADD opt /opt
  VOLUME /opt/chef
  EOF
  action :create
end

docker_image 'chef' do
  tag 'latest'
  source '/chefbuilder'
  action :build_if_missing
end

# start a volume container
docker_container 'chef' do
  command 'true'
  repo 'chef'
  action :create
end

# mount it from another container
docker_image "debian" do
  action :pull_if_missing
end

# Inspect the docker logs with test-kitchen bussers.
docker_container 'ohai_debian' do
  command '/opt/chef/embedded/bin/ohai platform'
  repo 'debian'
  volumes_from 'chef'
  not_if "[ ! -z `docker ps -qaf 'name=ohai_debian$'` ]"
  action :run
end

#############
# :autoremove
#############

# Inspect volume container with test-kitchen bussers.
docker_container 'sean_was_here' do
  command "touch /opt/chef/sean_was_here-#{Time.new.strftime('%Y%m%d%H%M')}"
  repo 'debian'
  volumes_from 'chef'
  autoremove true
  not_if { ::File.exist? '/tmp/container_marker_sean_was_here' }
  notifies :run, 'execute[container_marker_sean_was_here]', :immediately
  action :run
end

execute 'container_marker_sean_was_here' do
  command 'touch /tmp/container_marker_sean_was_here'
  action :nothing
end
