# bob
Snapshot of my ever changing bash profile, including functions that make using AWS easier.

```
- use of bash functions to encapsulate AWS command line complexity
- functional devops, talk to many servers using map
- easy to adapt and extend

Examples:

# rent <instanceType> <count> <imageId> <zone> <securityids> <key>
rent m4.10xlarge 50
tag Project test `all`

# update and upgrade the OS on all servers in parallel
map 'apt-get update && apt-get upgrade'

# deploy content across all servers
map 'deploy'

# now we have 50 more servers active, get their IP addresses
map 'bob PublicIpAddress'

More examples:

# add raid0 array to a linux AWS instance
ebs 100 ; attach 
ebs 100 ; attach 
raid0

# create a snapshot of a EBS volume
snapshot <volumeId>

# send that snapshot to another region
sendsnap <region>

# simple things.. send a text to my iPhone
message <email> "server is up and running"

# simple things.. remember things in a redis server
redis "<redis command>"
redis "<redis command>"
redis "<redis command>"
flush
```
