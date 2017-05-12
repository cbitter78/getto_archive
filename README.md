# Getto Archive

This is a project for those who do not want to use RAID, or other well known and working archive methods.  `¯\_(ツ)_/¯` 


# Credit

Lots of help from this post: [rsync_snapshots](http://www.mikerubel.org/computers/rsync_snapshots/)

# Usage

Define these environment variables

```
export BK_DEVICE="/dev/sdb1"
export BK_FOLDER="/opt/backup/drive1"
export CMD_RSYNC="rsync -av --bwlimit=3200 --exclude=extra/* root@work:/app/samba/* /opt/backup/drive1/backup_000/"

```

Then run 

```
./make_snapshot.rb

```

