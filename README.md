# bob
Snapshot of my ever changing bash profile, including functions that make using AWS easier.

Examples:

## rent 50 servers:
```
# rent <instanceType> <count> <imageId> <zone> <securityids> <key>
rent m4.10xlarge 50
tag Project test `all`
```

## update and upgrade the OS on all servers in parallel
```
map 'me ; apt-get update && apt-get upgrade'
```

## deploy content across all servers
```
map 'deploy'
```

## now we have 50 more servers active.

More examples:

## add raid0 array to a linux AWS instance
```
ebs 100 ; attach 
ebs 100 ; attach 
raid0
```

## create a snapshot of a EBS volume
```
snapshot <volumeId>
```

## send that volume to another region
```
sendsnap <region>
```

## simple things.. send a text
```
message <email> "server is up and running"
```

## simple things.. remember things in a redis server
```
redis "<redis command>"
redis "<redis command>"
redis "<redis command>"
flush
```
