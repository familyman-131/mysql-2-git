#!/bin/bash
# first version mysql-2-git script, without encryption
# it's possible to use for small offices or private purposes
# where is the possibility of breaking is minimal
# you only need to upload a mysql_dump.gz to "uploading" dir
# after IN_CLOSE_WRITE event happened in "uploading" directory, script will start and make all magic
# /path/to/dir/DB-repo/uploading/ IN_CLOSE_WRITE /path/to/db-to-repo.sh $#
# $# - sends filename to script as ${INCRON_FILE_NAME}
###variables
DATE=`date +%d-%m-%Y`
TEMP_DIR="/path/to/dir/DB-repo/uploading/"
REPO_DIR="/path/to/dir/DB-repo/complete"
BARE_REPO="user@server:repo.git"
MAIN_LOG=/var/log/incron/incron.log
TEMP_LOG=/var/log/incron/${DATE}-${RANDOM}.log
INCRON_FILE_NAME=$(echo "$1")
MAIL_ADDR=email@domain.com
FTP_LOG="/path/to/log/file"
###functions
#check command exit status
res2log () {
if [ "$?" -eq 0 ]
then
    echo "`date` Success" >> ${TEMP_LOG}
    else
    echo "`date` Error" >> ${TEMP_LOG}
fi
}
#logfile delimiter
breakline () {
    echo "------------------------------" >> ${TEMP_LOG}
}
#mailto func to use in few places
mailto () {
    cat ${TEMP_LOG} >> ${MAIN_LOG}
    cat ${TEMP_LOG} | mail -s "${REPORT} ${DATE}" ${MAIL_ADDR}
    rm  ${TEMP_LOG}
}

###script
echo " " >> ${TEMP_LOG}
echo "################################### " >> ${TEMP_LOG}
echo " " >> ${TEMP_LOG}
echo "${DATE} ${INCRON_FILE_NAME} has arrived"  >> ${TEMP_LOG}
#checking file extension
echo "${INCRON_FILE_NAME}"  | grep -q .sql.gz
FILE_EXT_CHK=$(echo "$?")
if [ ${FILE_EXT_CHK} = 0 ]
    then
    #checking uploaded file extension, and send it to log
    FILE_EXT_CHK="file.ext is .sql.gz"
    echo "${FILE_EXT_CHK}"  >> ${TEMP_LOG}
    #checking compressed file integrity, and exit if it's broken (maybe client will try re-upload it)
    echo "checking compressed file integrity" >> ${TEMP_LOG}
    cd ${TEMP_DIR} && gunzip -t ${INCRON_FILE_NAME}
    GZ_REP=$(echo "$?")
    if [ ${GZ_REP} = 0  ]
        then
        REPORT="gzip integrity checking OK"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
        else
        REPORT="gzip integrity checking ERROR"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
        mailto
        exit
    fi
    #set DB filename, and send it to log
    DB_FILE_NAME=$(echo "${INCRON_FILE_NAME}" | sed s'/\.gz$//')
    echo "uploaded database is ${DB_FILE_NAME}" >> ${TEMP_LOG}
    breakline
    #get remote repo
    echo "get remote repo"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && /usr/bin/git fetch --all  && /usr/bin/git reset --hard origin/master && /usr/bin/git pull
    res2log
    breakline
    #remove old dump from local repo
    echo "remove old dump from local repo"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && rm ${DB_FILE_NAME}
    res2log
    breakline
    #moving uploaded file to local repo dir
    echo "moving uploaded file to local repo dir"  >> ${TEMP_LOG}
    cd ${TEMP_DIR} && mv ${INCRON_FILE_NAME} ${REPO_DIR}
    res2log
    breakline
    #uncompress file
    echo "uncompress file"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && /bin/gunzip ${INCRON_FILE_NAME}
    res2log
    breakline
    #add DB file to local repo
    echo "commit DB file to local repo"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && /usr/bin/git add ${DB_FILE_NAME} &&  /usr/bin/git commit -m "${DB_FILE_NAME} backup added"
    res2log
    breakline
    #git push
    echo "git push to remote repo"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && /usr/bin/git push
    res2log
    breakline
    REPORT=$(echo "${INCRON_FILE_NAME} uploaded to ${TEMP_DIR}")
    else
    FILE_EXT_CHK="file.ext is NOT .sql.gz"
    echo "${FILE_EXT_CHK}"  >> ${TEMP_LOG}
    REPORT="bullshit uploaded to ${TEMP_DIR}, check ftp logs"
    echo "removing the bullshit file  ${INCRON_FILE_NAME}" >> ${TEMP_LOG}
    cd ${TEMP_DIR} && rm ${INCRON_FILE_NAME}
    res2log
    breakline
    tail -n 20 ${FTP_LOG} >> ${TEMP_LOG}
fi

#removing 6+ hours old broken .sql.gz files
echo "removing 6+ hours old broken .sql.gz files, listed below"  >> ${TEMP_LOG}
find ${TEMP_DIR} -type f -mmin +360  -print >> ${TEMP_LOG} -delete
res2log
breakline
mailto
