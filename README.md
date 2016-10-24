# mysql-2-git-enc
use it with incron, for automatically adding mysql dump to git repository

you need to upload two files  
file with one-time password inside filename.otp.key, which encrypted with open rsa key  
and file with sql dump in encrypted with OTP tar.gz archive inside filename.enc.file 

you need three directory  
tmp - for files in process of uploading  
complete - for key files   
repo - for repository with worktree

after IN_CLOSE_WRITE event happened in tmp directory, script will start and make all magic  
incrontab must contain something like  
/path/to/dir/DB-repo/tmp/ IN_CLOSE_WRITE /path/to/db-to-repo.sh $#  
where $# - sends filename to script as ${INCRON_FILE_NAME}
