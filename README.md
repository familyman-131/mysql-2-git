# mysql-2-git-enc
use it with incron, for automatically adding mysql dump to git repository

you need to upload two files 
file with one-time password inside, which encrypted with open rsa key 
and file with sql dump in tar.gz archive

you need three directory
tmp - for files in process of uploading
complete - for key files 
repo - for repository with worktree

after IN_CLOSE_WRITE event happened in tmp directory, script will start and make all magic
