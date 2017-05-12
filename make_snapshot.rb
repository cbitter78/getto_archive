#!/usr/bin/env ruby

require 'fileutils'
require 'logger'


@bk_device = ENV.fetch('BK_DEVICE', '/dev/sdb1')
@bk_folder = ENV.fetch('BK_FOLDER', '/opt/backup/drive1')
@bk_num    = Integer(ENV.fetch('BK_NUM', '365')) rescue 365

# No more backups then 999 because the folder names are padded to 3 number.  ie backup_###
@bk_num = 999 if @bk_num > 999

@mount     = ENV.fetch('CMD_MOUNT', '/bin/mount')
@rsync     = ENV.fetch('CMD_RSYNC', 'rsync -av --bwlimit=3200 --exclude=extra/* root@work:/app/samba/* /opt/backup/drive1/backup_000/')
@cp        = ENV.fetch('CMD_CP', '/bin/cp')
@log = Logger.new(STDOUT)

unless Process.uid == 0
  @log.fatal('Not running as root.  Root is requried.')
  exit(1)
end

unless system("#{@mount} -o remount,rw #{@bk_device} #{@bk_folder}") 
	@log.fatal("Could not remount #{@bk_device} #{@bk_folder}.")
	exit(1)
end

Dir.chdir(@bk_folder)
@log.info("Changing directory to #{@bk_folder}")

# Get a list of all the current backup folders. 
bk_folders = []
Dir.glob('./backup_**').map do |f|
	bk_folders << f if File.directory?(f)
end
bk_folders-= ["./backup_000"]          # Remove backup_000 from the list beccause its speical. 
bk_folders = bk_folders.sort.reverse   # Reverse sort so the oldest folder will be first. 

# Find the oldest folder number 
unless bk_folders.empty?
	oldest_folder_num = Integer(bk_folders.first.match(/(\d+)/)[0].to_i) rescue nil
	if oldest_folder_num.nil?
		@log.fatal("Could not figure out the oldest folder. #{bk_folders}")
		exit(2)
	end


	# if we are at the max backups then we need to nuke the oldest one.
	if oldest_folder_num >= @bk_num
		FileUtils.rm_rf(bk_folders.first)
		bk_folders.shift
		oldest_folder_num =-1
	end

	# Move all the backup folders up by one. For exmaple given 9 folders:
	#  backup_008 -- moving to --> backup_009
	#  backup_007 -- moving to --> backup_008
	#  backup_006 -- moving to --> backup_007
	#  backup_005 -- moving to --> backup_006
	#  backup_004 -- moving to --> backup_005
	#  backup_003 -- moving to --> backup_004
	#  backup_002 -- moving to --> backup_003
	#  backup_001 -- moving to --> backup_002 
	(0...oldest_folder_num).to_a.reverse.each do |n|
		c_dir = "backup_#{(n + 1).to_s.rjust(3, '0')}"
		n_dir = "backup_#{(n + 2).to_s.rjust(3, '0')}"
		@log.info("Moving #{c_dir} -- moving to --> #{n_dir}")
		FileUtils.mv(c_dir, n_dir)
	end
end

@log.info("Making hard link copy: backup_000 -> backup_001")
unless system("#{@cp} -al backup_000 backup_001") 
	@log.fatal("Could not make a hard link copy of backup_000 to backup_001")
	exit(3)
end

@log.info("Starting Rsync.....")
system("#{@rsync}")
@log.info("Rsync Done.")

FileUtils.touch("./backup_000/#{Time.now.strftime('%Y_%m_%d__%H_%M_%S_%9N.log')}")


unless system("#{@mount} -o remount,ro #{@bk_device} #{@bk_folder}") 
	@log.fatal("Could not remount #{@bk_device} #{@bk_folder}.")
	exit(1)
end




