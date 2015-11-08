export PATH=$PATH:/usr/local/bin:/usr/local/sbin
# if [ -f /usr/local/etc/bash_completion ]; then
# . /usr/local/etc/bash_completion
# fi

# No warranty for any purpose, opening a conversation.
# This is an excerpt from my ever evolving .profile.
# grasswood@icloud.com

# useful variables
export CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad
export GREP_OPTIONS="--color=auto"
export HOSTNAME=$HOSTNAME ; launchctl setenv HOSTNAME $HOSTNAME
export host=`hostname`
export volume= device= snapshot= onboot= dir= bucket=

# measure execution times
alias timed="TIMEFORMAT='%R'; time"

# my servers talk and text me
function message { osascript -e "tell application \"Messages\" to send \"$2\" to buddy \"$1\" " ; }
function sms { osascript -e "tell application "Messages" to send "test" to (buddy 1 whose handle is "<some phone number>") ; }

# ask user to confirm before comitting to a potentially dangerous action
function confirm { x=$[1+$[RANDOM%99999]] ; z="$@ Enter $x to confirm: " ; echo -ne $z ; say $z ; read a ; [ $a -eq $x ] || kill -INT $$ ; say ok ; }
function lock    { x=$[1+$[RANDOM%99999]] ; message <some email address> $x ; z="$@ Enter code:" ; echo -ne $z" " ; say $z ; read a ; [ $a -eq $x ] || kill -INT $$ ; say ok ; }

# usually have a redis box remember things: redis "raw string of redis commands", finally.. "flush"
function redis { pipeline+="$1\r\n" ; }
function flush { echo -e "$pipeline" | ncat --send-only localhost 6379 ; pipeline= ; }

# just ask bob, bob knows: bob InstanceType | bob edit | bob help | bob hint | etc 
function bob { x=$1 ; shift ; i=${@-$instance} ; case $x in
   help) cat ~/help ;;
   hint) grep "function $1" ~/.bash_profile ;;
   grep) grep $1 ~/.bash_profile ;;
   edit) cp ~/.bash_profile /$dir/ ; vi ~/.bash_profile +/"function $1" ; source ~/.bash_profile ;;
   diff) a=${1-"/$dir/.bash_profile"} ; b=${2-"~/.bash_profile"} ; echo $a $b ; diff -y --suppress-common-lines $a $b ;;
 backup) cp ~/.bash_profile /$dir/ ; rsync -a /$dir /Volumes/PORTABLE ; diskutil unmount /Volumes/PORTABLE ;;
    log) aws ec2 get-console-output --instance-id $i ;; hi) v="$instanceType at $ip running version 0.7.15.54 on $instance in $region" ; echo $v ;;
      *) printf '%s\n' $( aws --output=text ec2 describe-instances --instance-ids $i --query "Reservations[*].Instances[*].$x" ) ;; esac ; }

# set of servers is stored in servers, hard linked to .dsh/machines.list
touch ~/slices ; mkdir -p .dsh ; touch .dsh/machines.list ; ln -f .dsh/machines.list ~/servers

# functional devops: map 'me ; <command> ; <command>'
function me { echo -n $host" " ; }
function map { dsh -F100 -ca "$@" ; }
function maps  { g=${1:?"Usage: maps <group>"} ; shift ; cp .dsh/group/$g.ids ~/slices ; cp .dsh/group/$g ~/servers ; dsh -cg $g "$@" ; }
function zap { f=${1-"slices"} ; : > $f ; }
function save  { cp .dsh/machines.list .dsh/group/$1 ; cp ~/slices .dsh/group/$1.ids ; zap ; }
function list { pushd .dsh/group/ &>/dev/null ; wc -l * | grep -v total | grep -v *.ids ; popd &>/dev/null ; }
function add { cat $1 >> ~/servers ; }
function sub { t=/tmp/$BASHPID ; grep -vf $1 ~/servers > $t ; mv $t ~/servers ; }
function go { s=${server:?"Remember to set server"} ; ssh $s $@ ; }
function ips { awk -F"@" '{print $2}' ~/.dsh/machines.list ; }
function all { printf '%s\n' $( aws --output=text ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" ) ; }

# tag resources: tag <key> <value> `all`
function tag { aws ec2 create-tags --tags Key=$1,Value=$2 --resources $3 ; }
function xyz { tag Project xyz $1 ; echo $1 ; }

# review account
function audit { echo "SLICES" ; bob InstanceType `all` | sort | uniq -c | sort -nr ;
   aws --output=text ec2 describe-volumes | awk '/VOLUMES/ { s = s+$5 }; END { print "EBS: " s }' 
   echo -n "SNAP: " ; aws ec2 describe-snapshots | wc -l ; }

# create an AMI from this or another instance: ami <name> <instance>
function ami { i=${2-$instance} ; sync ;  ami=`aws ec2 create-image --instance-id $i --name "$1"` ; xyz $ami ; }

# launch multiple instances: rent <instanceType> <count> <imageId> <zone> <securityids> <key>
function rent { t=${1-"m4.xlarge"} ; c=${2-"1"} ; i=${3-$imageId} ; z=${4-$zone} ; s=${5-"sg-14190470"} ; k=${6-"<change this>"} ;
   aws --output=json ec2 run-instances --image-id $i --security-group-ids $s --placement AvailabilityZone=$z,Tenancy=default --instance-type $t \
   --key-name $k --count $c | awk -F'"' '/InstanceId/ {print $4}' >> ~/slices ;
    until [ $( bob State.Name $( < ~/slices ) | grep -c pending ) -eq 0 ] ; do sleep 5 ; done ;
    printf 'root@%s\n' $( bob PublicIpAddress `<~/slices` ) > ~/servers ; wc -l ~/slices ; tag Project Z2 `all` ; }

# terminate current instance or specified instances
function headshot  { i=${1-$instance} ; aws ec2 terminate-instances --instance-ids $i ; }

### aws ebs ###
function vol { x=$1 ; shift ; v=${@-$volume} ; aws --output=text ec2 describe-volumes --volume-ids $v --query "Volumes[*].$x" ; }
function volReady { volume=$1 ; while [ `vol State` != "available" ] ; do sleep $[1+$[RANDOM%20]] ; done ; }
function ebs { volume=`aws ec2 create-volume --size $1 --availability-zone $zone --volume-type gp2 --output=json | awk -F'"' '/VolumeId/ { print $4 }'` ; volReady $volume ; xyz $volume ; } 
function delete { v=${1-$volume} ; volReady $v ; aws ec2 delete-volume --volume-id $v ; volume= ; }
function detach { v=${1-$volume} ; status=`aws ec2 detach-volume --volume-id $v` ; volReady $v ; }
function attach { v=${1-$volume} ; i=${2-$instance} ; volReady $v ; for x in {b..z} ; do device="/dev/xvd$x" ; [ ! -e "$device" ] && break ; done ;
   status=`aws ec2 attach-volume --volume-id $v --instance-id $i --device $device --output=json`
   while [ ! -e "$device" ] ; do sleep $[1+$[RANDOM%10]] ; done ; echo $device ; }
function wipe   { d=${1-$device} ; ionice -c3 dd if=/dev/urandom of=$d ; }
function warmup { d=${1-$device} ; ionice -c3 dd if=$d of=/dev/null bs=1G; }

# raid all attached devices, excluding the root volume, wether ssd or ebs, then mount on /mnt
function devices { ls /dev/xv* | grep -v xvda ; }
function raid0 { umount /mnt ; mkfs.btrfs -f -m raid0 -d raid0 `devices` ; mount /dev/xvdb /mnt ; }
function raid10 { umount /mnt ; mkfs.btrfs -f -m raid10 -d raid10 `devices` ; mount /dev/xvdb /mnt ; }
function mdraid0 { umount /mnt ; c=`devices | wc -l` ; mdadm -Cv /dev/md0 -l0 -n$c `devices` ; mkfs.xfs /dev/md0 ; mount /dev/md0 /mnt ; }

### aws snapshots ### snap Progress|VolumeSize|OwnerId|State|StartTime|VolumeId|Description <snapshotId>
function snap { x=$1 ; shift ; i=${@-$snapshot} ; aws --output=text ec2 describe-snapshots --snapshot-ids $i --query "Snapshots[*].$x" ; }
function snapshot { v=${1-$volume} ; snapshot=`aws ec2 create-snapshot --volume-id $v --description $instance --output=json | awk -F'"' '/SnapshotId/ {print $4 }'` ; xyz $snapshot ; }
function restorevol { s=${1-$snapshot} ; volume=`aws ec2 create-volume --availability-zone $zone --snapshot-id $s --volume-type gp2 --output=json | awk -F'"' '/VolumeId/ { print $4}'` ; xyz $volume ; }
function sendsnap { aws --region $1 ec2 copy-snapshot --source-region "$region" --source-snapshot-id $snapshot --output=json --description "Copy of $snapshot" | awk -F'"' '/SnapshotId/ {print $4}' ; }

### backup and restore directory to and from ebs volumes: backup <directory> ; restore <directory>
function storage { m=${2:?"Usage: storage <size> <mountpoint>"} ; ebs $1 ; attach ; mkfs.xfs $device ; mount $device $m ; }
function backup { d=${1-"/mnt"} ; m="/tmp/`echo "$d" | sha256 -x`" ; mkdir -p $m ; size=`du -sm $d | awk '{print int(1+$1/1000)}'` ; storage $size $m ;
   ionice -c 3 rsync -l -av $d/ $m/ ; umount $m ; rmdir $m ; detach ; snapshot ; echo $volume > ~/$d-backup ; }
function restore { d=${1:?"Usage: restore <directory>"} ; m="/tmp/`echo "$d" | sha256 -x`" ; mkdir -p $m $d ;
   attach `cat ~/$d-backup` ; mount $device $m ; ionice -c 3 rsync --delete -l -av $m/ $d ; umount $m ; rmdir $m ; detach ; }

### aws s3 ###
function download { d=${1:?"Usage: download <directory>"} ; aws s3 sync s3://$bucket/$d $d ; }
function upload { d=${1-"/mnt"} ; aws s3 sync $d s3://$bucket/$d ; }

### content distribution ###
function prep { d=${1:?"Usage: prep <name>"} ; aws s3 sync /$d s3://$bucket/$d ; }
function deploy { d=${1:?"Usage: deploy <name>"} ; mkdir -p /$d ; aws s3 sync s3://$bucket/$d /$d ;
   cd /$d ; [ -e ./install.sh ] && [ -x ./install.sh ] && ./install.sh ; }

### make new AMI from current instance ###
function goldmaster { d=${1-"/upgrade"} ; mkdir -p $d ; cd $d ; dpkg --get-selections > packages ;
   cp /etc/bash.bashrc $d/ ; cp /etc/rc.local $d/ ; cp ~/.ssh/authorized_keys $d/ ; prep upgrade ; }

### super simple disk speed testing ###
# GBtest ; timed copytest `seq 1 10`
function GBtest { dd if=/dev/urandom of=test bs=1G count=1 iflag=fullblock ; }
function copytest { for i in "$@" ; do cp test test.$i ; done ; }

#flow logs
export flowlog stream eni
function ChangeAccountFlowLog { x=$( aws --output=text ec2 describe-flow-logs ) ; flowlog=$( echo $x | awk '{ print $6 }' ) ; arn=$( echo $x | awk '{ print $3 }' ) ; }
function getENI { i=${1-$instance} ; eni=$( aws ec2 describe-instances --output text --instance-ids $i | awk '/NETWORKINTERFACES/ {print $3}' ) ; echo $eni ; }
function getFlowLog { i=${1-$instance} ; geteni $i ; aws --output=text logs get-log-events --log-group-name $flowlog --log-stream-name $eni"-accept" >x ;  }
function ipsources { echo "IPsources" ; cat x | awk '{ s[$6]++ } END { for (i in s) { printf "%6s %15s\n", s[i], i } }' | sort -nr | head ; }
function ipsinks { echo "IPsinks" ; cat x | awk '{ x[$7]++ } END { for (i in x) { printf "%6s %15s\n", x[i], i } }' | sort -nr | head ; }

# function flowlogbysink { cat x | grep -v REJECT | awk '$6=="172.31.25.126" { bytes[$7]+=$12} END{for(i in bytes) print i,bytes[i]}'  | sort -nrk2 ; }
# function flowlogbysource { cat x | grep -v REJECT | awk '$7=="172.31.25.126" { bytes[$6]+=$12} END{for(ip in bytes) print ip,bytes[ip]}'  | sort -nrk2 ; }
# function flowlogbyconnection { cat x | awk '{ s[$6" to "$7]++ } END { for (i in s) { printf "%6s %15s\n", s[i], i } }' | sort -nr | head ; }

# turn multiple instances on or off
function on { aws ec2 start-instances --instance-ids `<slices` ; } 
function off { aws --dry-run ec2 stop-instances --instance-ids `<slices` ; }

# everybody there?
function pingall { for ip in `awk -F"@" '{print $2}' ~/servers` ; do printf '%s\t%.0s%.0s%.0s%s%s\n' $ip $( ping -qc1 <some IP> | grep round ) ; done ; } 

# laptop
function www { open $( awk -F"@" '{print "http://"$2}' ~/servers) ; }


export -F message sms confirm lock redis flush bob functional me map maps zap save list add sub go ips all tag xyz audit ami rent headshot vol volReady ebs delete detach attach wipe warmup devices raid0 raid10 mdraid0 snap snapshot restorevol sendsnap storage backup restore download upload prep deploy goldmaster GBtest copytest ChangeAccountFlowLog getENI getFlowLog ipsources ipsinks function function function on off pingall www
