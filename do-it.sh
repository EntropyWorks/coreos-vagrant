#!/bin/bash
#asciinema rec -w 1 -t do-it.sh -c ./do-it.sh -y /tmp/do-it.record
#
# You can change these to whatever you need to prevent confliting 
# ip ranges.
#
#set -x 
IP_VIRTUALBOX="192.168.240"
IP_VMWARE="172.17.8"

# These are just for testing and should never be used in production ever!
WSREP_SST_PASSWORD="foobar"
MYSQL_ROOT_PASSWORD="root" 

# Where the https://github.com/EntropyWorks/fleet-units-galera-cluster repo is placed
FLEET_UNIT_DIR="/tmp/fleet-units-galera-cluster"

# Sets default provider so you don't need to use -p on the commandline
PROVIDER=${VAGRANT_DEFAULT_PROVIDER}

# NOTICE: Uncomment if your script depends on bashisms.
if [ -z "$BASH_VERSION" ]; then bash $0 $@ ; exit $? ; fi
tempfile=$(mktemp /tmp/do-it.XXXXXX)  || { echo "Failed to create temp file"; exit 1; }

function cleanup {
  rm -rf ${tempfile}
  exit
}

function fail {
    errcode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorcode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}"
    # do some error handling, cleanup, logging, notification
    # $BASH_COMMAND contains the command that was being executed at the time of the trap
    # ${BASH_LINENO[0]} contains the line number in the script of that command
    # exit the script or return to try again, etc.
    cleanup
    exit $errcode  # or use some other value or do return instead
}

# Catch the crtl-c and others nicely
trap cleanup EXIT SIGHUP SIGINT SIGTERM
trap fail ERR


#echo "Before"
#for i ; do echo - $i ; done

# Code template for parsing command line parameters using only portable shell
# code, while handling both long and short params, handling '-f file' and
# '-f=file' style param data and also capturing non-parameters to be inserted
# back into the shell positional parameters.
function command_readme(){
cat << EOF

Very basic commands so far...

 -p <provider> Sets your provider (supports vmware and virtualbox)   
 -D Destroys everything when re-run. Without only core-# are removed

EOF
cleanup 
exit
}

while [ -n "$1" ]; do
        # Copy so we can modify it (can't modify $1)
        OPT="$1"
        # Detect argument termination
        if [ x"$OPT" = x"--" ]; then
                shift
                for OPT ; do
                        REMAINS="$REMAINS \"$OPT\""
                done
                break
        fi
        # Parse current opt
        while [ x"$OPT" != x"-" ] ; do
                case "$OPT" in
                        -p* | --provider )
                                PROVIDER="$2"
                                shift
                                ;;
                        -h* | --help )
                                command_readme
                                shift
                                ;;
                        # Anything unknown is recorded for later
                        * )
                                REMAINS="$REMAINS \"$OPT\""
                                break
                                ;;
                esac
                # Check for multiple short options
                # NOTICE: be sure to update this pattern to match valid options
                NEXTOPT="${OPT#-[p]}" # try removing single short opt
                if [ x"$OPT" != x"$NEXTOPT" ] ; then
                        OPT="-$NEXTOPT"  # multiple short opts, keep going
                else
                        break  # long form, exit inner loop
                fi
        done
        # Done with that param. move to next
        shift
done
# Set the non-parameters back into the positional parameters ($1 $2 ..)
eval set -- $REMAINS

#echo -e "After: \n configfile='$CONFIGFILE' \n provider='$PROVIDER' \n force='$FORCE' \n retry='$RETRY' \n remains='$REMAINS'"
#for i ; do echo - $i ; done

function msg(){
    if [ -f `which figlet` ] ; then
        #figlet -w 150 -c  -f stampatello "\-\-\-\-\-\-\-\-\-\-\-\-\-\-"
        echo 
        figlet -w 150 -f stampatello $@
        echo 
        #figlet -w 150 -c  -f stampatello "\-\-\-\-\-\-\-\-\-\-\-\-\-\-"
    else
        line="------------------------------------------------"
        echo ${line}
        echo $@
        echo ${line}
    fi
}

# Doing this make it easy to run virtualbox and then switch to
# using vmware_fusion. Other wise the there are network collisions 
CHOICE=${PROVIDER:-virtualbox}
if [ ${CHOICE} == virtualbox ] ; then 
    IP=${IP_VIRTUALBOX}
    cat config.rb.sample | sed -e s/__CHANGE_IP__/${IP}/g > config.rb
else
    IP=${IP_VMWARE}
    cat config.rb.sample | sed -e s/__CHANGE_IP__/${IP}/g > config.rb
fi


function destroy_vagrant_boxes(){
    # Start from statch again. Is you want to just destroy
    # the minions core-XX just run the following
    #  vagrant destroy -f core-0{1..3}
    msg Destroy old vagrant boxes
    #if [ -n ${DESTROY} ] ; then 
    #    for vm in $(vagrant status | grep core | awk '{ print $1 }') ; do
    #        vagrant destroy -f ${vm}
    #    done
    # else
        vagrant destroy -f

        # Removing old user-data.*.yaml files that contain etcd
        # discovery url that shouldn't be reused
        if [ -f user-data.master.yaml ] ; then
            rm user-data.master.yaml 
        fi 
        if [ -f user-data.node.yaml ] ; then 
            rm user-data.node.yaml
        fi
    #fi
}

function build_vagrant_boxes(){
    # Building the master-01 first so I can capture the SSH port forwarding
    # to use later.
    msg "Build new vagrant boxes using ${PROVIDER:-virtualbox}"
    vagrant up --provider ${PROVIDER:-virtualbox} master-01
    vagrant up --provider ${PROVIDER:-virtualbox} 
}

function ssh_config(){
    # I have a way to manage my ssh config. Create starting with numbers to
    # fix the order the ~/.ssh/config is created
    # alias ssh='[[ -d ~/.ssh/config.d ]] &&  cat ~/.ssh/config.d/*.cfg > ~/.ssh/config ; /usr/bin/ssh'
    if [ -f  ~/.ssh/config.d/01-vagrant.cfg ] ; then
        vagrant ssh-config > ~/.ssh/config.d/01-vagrant.cfg
        cp ~/.ssh/config.d/01-vagrant.cfg /tmp/01-vagrant.cfg
    else
        vagrant ssh-config > /tmp/01-vagrant.cfg
    fi
}

function set_fleetctl_env(){
    # Since there may be other VM's running already I check to see
    # what the port forwarding for SSH has been set to.

    vagrant ssh-config master-01 2>&1 >  $tempfile

    msg "Setting tunnel port to ${TUNNEL_PORT}"

    export TUNNEL_HOST=$(cat $tempfile |grep "HostName" | awk '{print $2}')
    export TUNNEL_PORT=$(cat $tempfile |grep "Port" | awk '{print $2}')
    export FLEETCTL_TUNNEL=${TUNNEL_HOST}:${TUNNEL_PORT}
    export FLEETCTL_SSH_USERNAME=core
    export FLEETCTL_STRICT_HOST_KEY_CHECKING=false
    export FLEETCTL_KNOWN_HOSTS_FILE=/dev/null

cat << EOF

    export TUNNEL_HOST=$(cat $tempfile |grep "HostName" | awk '{print $2}')
    export TUNNEL_PORT=$(cat $tempfile |grep "Port" | awk '{print $2}')
    export FLEETCTL_TUNNEL=${TUNNEL_HOST}:${TUNNEL_PORT}
    export FLEETCTL_SSH_USERNAME=core
    export FLEETCTL_STRICT_HOST_KEY_CHECKING=false
    export FLEETCTL_KNOWN_HOSTS_FILE=/dev/null

EOF
}

function check_fleet_machines(){
    # Verify that machines are seen 
    msg "Checking fleet machines"
    FLEETCTL_TUNNEL=${TUNNEL_HOST}:${TUNNEL_PORT} fleetctl list-machines
}


function checkout_fleet_units(){
  if [ ! -d /tmp/fleet-units-galera-cluster ] ; then
    msg "Checkout fleet units galera cluster"
    git clone https://github.com/EntropyWorks/fleet-units-galera-cluster.git ${FLEET_UNIT_DIR}
  fi
  msg "Create galera@.service fleet-unit"
  for file in $(ls -1 /tmp/fleet-units-galera-cluster/*\.template |sed -e s/\.template$//g ) ; do
      cat  ${FLEET_UNIT_DIR}/${file}@.template | \
        sed -e s/__FLEETCTL_ETC_ENDPOINT__/${IP}.11:4001/g \
        -e s/__ETC_LISTEN_CLIENT_URLS__/${IP}.11:4001/g \
        -e s/__CHANGE_WSREP_SST_PASSWORD__/${WSREP_SST_PASSWORD}/g \
        -e s/__CHANGE_MYSQL_ROOT_PASSWORD__/${MYSQL_ROOT_PASSWORD}/g \
        > ${FLEET_UNIT_DIR}/${file}@.service
  done
}

function check_submit_fleet_units(){
    # Submitting the fleet units to be started later
    msg "Submit fleet units"
    fleetctl submit ${FLEET_UNIT_DIR}/*.service
    fleetctl list-unit-files
}

function start_mysql(){
    # Start the mysql first
    msg Start the fleet-units
    for i in 1 2 3 ; do
        msg "fleetctl start galera@${i}.service"
        fleetctl start galera@${i}.service
        while true ; do
            echo -n "."
            fleetctl journal --lines 1000 galera@${i}.service 2>/dev/null | grep "mysqld: ready for connections" && break
            sleep 1
        done
        # Start the sidekick now that mysql is running.`
        msg "fleetctl start galera-sidekick@${i}.service"
        fleetctl start galera-sidekick@${i}.service
        # Don't start the next mysql process until the sidekick reports in.
        while true ; do
             echo -n "."
             etcdctl ls /galera/galera-${i} 2>/dev/null && break
            sleep 1
        done
        echo ""
        msg "Verify galera-sidekick@${i}.service made it into etcd"
        echo "galera-sidekick@${i}.service has set /galera/galera-${i} to $(etcdctl get /galera/galera-${i})"
    done 
}


function check_sidekick(){
    # Check that the sidekick has recorded the flannel IP to etcd
    msg "Sidekick reported"
    for i in 1 2 3 ; do 
       #echo "/galera/galera-${i} = $(etcdctl get /galera/galera-${i})"
       echo "galera-sidekick@${i}.service has set /galera/galera-${i} to $(etcdctl get /galera/galera-${i})"
    done
}

function check_mysql(){
    # Check if mysql it ready for connections
    for i in 1 2 3 ; do
        while true ; do
            echo -n "."
            fleetctl journal --lines 1000 galera@${i}.service 2>/dev/null | grep "mysqld: ready for connections" && break
            sleep 1
        done
    done
    echo " Done!"
}

function get_results(){
    # this 
    for i in $(vagrant status | grep core | grep running | awk '{print $1}') ; do 
        ssh -F /tmp/01-vagrant.cfg  ${i} -t "docker exec -i -t \$(docker ps | grep galera |awk '{print \$1}') mysql -uroot -proot -e 'show status like \"wsrep_inc%\";'" 
    done
}

# The order to run the above functions.
destroy_vagrant_boxes
build_vagrant_boxes
sleep 5
ssh_config
sleep 5
set_fleetctl_env
sleep 5
check_fleet_machines
checkout_fleet_units
check_submit_fleet_units
sleep 5
start_mysql
check_sidekick

#check_mysql
#get_results
