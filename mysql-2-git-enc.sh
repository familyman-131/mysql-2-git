#!/bin/bash
###################################################
###variables
###################################################
DATE=`date +%d-%m-%Y`
TEMP_DIR="/path/to/dir/DB-repo/tmp/"
UPLOADED_DIR="/path/to/dir/DB-repo/complete/"
REPO_DIR="/path/to/dir/DB-repo/repo/"
BARE_REPO="user@server:repo.git"
PRIVATE_KEY="/path/to/.ssh/id_rsa"
MAIN_LOG=/var/log/incron/incron.log
TEMP_LOG=/var/log/incron/${DATE}-${RANDOM}.log
INCRON_FILE_NAME=$(echo "$1")
FTP_LOG="/path/to/log/file"
MAIL_ADDR=email@domain.com
###################################################
###functions
###################################################
#check command exit status
res2log () {
if [ "$?" -eq 0 ]
then
    echo "`date` SUCCESS" >> ${TEMP_LOG}
else
    echo "`date` ERROR" >> ${TEMP_LOG}
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
#add unpacked file to local repo and push to remote repo func
db2repo () {
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
    cd  ${UPLOADED_DIR} && mv ${DB_FILE_NAME} ${REPO_DIR}
    res2log
    breakline
    # add DB file to local repo
    echo "commit DB file to local repo"  >> ${TEMP_LOG}
    cd ${REPO_DIR} && /usr/bin/git add ${DB_FILE_NAME} &&  /usr/bin/git commit -m "${DB_FILE_NAME} backup added"
    res2log
    breakline
    #git push
    echo "git push to remote repo"  >> ${TEMP_LOG}
    breakline
    cd ${REPO_DIR} && /usr/bin/git push
        if [ "$?" -eq 0 ]
        then
            REPORT="adding ${DB_FILE_NAME} to ${BARE_REPO} SUCCESS"
            echo "${REPORT}"  >> ${TEMP_LOG}
        else
            REPORT="adding ${DB_FILE_NAME} to ${BARE_REPO} ERROR"
            echo "${REPORT}"  >> ${TEMP_LOG}
        fi
    breakline
    mailto
}
##get one-time password and check integrity of keyfile
get-passwd () {
echo "checking keyfile integrity and get one-time password" >> ${TEMP_LOG}
OTP=$( cd  ${UPLOADED_DIR}  && openssl rsautl -decrypt -inkey ${PRIVATE_KEY} -in ${KEY_FILE_NAME} )
DEC_REP=${OTP}
    if [ -z "${DEC_REP}" ]
    then
        REPORT="keyfile integrity checking ERROR"
        echo "${REPORT}"  >> ${TEMP_LOG}
        echo "deleting broken keyfile" >> ${TEMP_LOG}
        cd  ${UPLOADED_DIR}  && rm  ${KEY_FILE_NAME}
        res2log
        breakline
        mailto
        exit
    else
        REPORT="keyfile integrity checking SUCCESS"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
    fi
}
##decrypt enc.file
decrypt () {
echo "decrypting encrypted file to ${UPLOADED_DIR}" >> ${TEMP_LOG}
cd  ${TEMP_DIR}  && openssl enc -aes-256-cbc -d -k ${OTP} -in ${ENC_FILE_NAME} -out ${UPLOADED_DIR}${DEC_FILE_NAME}
DEC_REP=$(echo "$?")
    if [ ${DEC_REP} = 0  ]
    then
        REPORT=".enc file has been decrypted SUCCESS"
        echo "${REPORT}"  >> ${TEMP_LOG}
        echo "deleting unnesesarry keyfile from  ${UPLOADED_DIR} " >> ${TEMP_LOG}
        cd  ${UPLOADED_DIR}  && rm ${KEY_FILE_NAME} 
        res2log
        echo "deleting unnesesarry encrypted file from  ${TEMP_DIR} " >> ${TEMP_LOG}
        cd  ${TEMP_DIR}  && rm ${ENC_FILE_NAME}
        res2log
        breakline
    else
        REPORT=".enc file in ${TEMP_DIR} has not been decrypted ERROR"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
        mailto
        exit
    fi
}
#check unencrypted compressed file integrity
gz-test () {
echo "checking compressed file integrity" >> ${TEMP_LOG}
cd ${UPLOADED_DIR} && gunzip -t ${DEC_FILE_NAME}
GZ_REP=$(echo "$?")
    if [ ${GZ_REP} = 0  ]
    then
        REPORT="gzip integrity checking OK"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
    else
        REPORT="gzip integrity checking ERROR"
        echo "${REPORT}"  >> ${TEMP_LOG}
        echo "deleting broken decrypted file" >> ${TEMP_LOG}
        cd  ${UPLOADED_DIR}  && rm ${DEC_FILE_NAME}
        res2log
        breakline
        mailto
        exit
    fi
}
#uncompress
uncompress () {
echo "uncompress uploaded file" >> ${TEMP_LOG}
cd  ${UPLOADED_DIR} && tar -xvf ${DEC_FILE_NAME}
GZ_REP=$(echo "$?")
    if [ ${GZ_REP} = 0  ]
    then
        REPORT="file unpacked SUCCESS"
        echo "${REPORT}"  >> ${TEMP_LOG}
        breakline
    else
        REPORT="file unpacking ERROR"
        echo "${REPORT}"  >> ${TEMP_LOG}
        echo "deleting broken decrypted file" >> ${TEMP_LOG}
        cd  ${UPLOADED_DIR}  && rm ${DEC_FILE_NAME}
        res2log
        breakline
        mailto
        exit
    fi
}
#get db file name 
get-db-name () {
DB_FILE_NAME=$(cd  ${UPLOADED_DIR} && tar -tf ${DEC_FILE_NAME} )
echo "uploaded database is ${DB_FILE_NAME}" >> ${TEMP_LOG}
breakline
}
#remove decrypted archive after unpack
rm-decrypted () {
echo "remove ${DEC_FILE_NAME} after unpack"  >> ${TEMP_LOG}
cd  ${UPLOADED_DIR}  && rm ${DEC_FILE_NAME}
res2log
breakline
}
###################################################
###script
###################################################
echo " " >> ${TEMP_LOG}
echo "################################### " >> ${TEMP_LOG}
echo " " >> ${TEMP_LOG}
echo "${DATE} ${INCRON_FILE_NAME} has arrived"  >> ${TEMP_LOG}
#removing 6+ hours old uploaded files in ${TEMP_DIR}
echo "removing 6+ hours old uploaded files in ${TEMP_DIR}, listed below"  >> ${TEMP_LOG}
find ${TEMP_DIR} -type f -mmin +360  -print >> ${TEMP_LOG} -delete
res2log
breakline
#checking file extension
echo "${INCRON_FILE_NAME}"  | grep -q .otp.key
FILE_EXT_CHK=$(echo "$?")
if [ ${FILE_EXT_CHK} = 0 ]
then
    #checking uploaded file extension, and send it to log
    FILE_EXT_CHK="file.ext is .otp.key SUCCESS"
    echo "${FILE_EXT_CHK}"  >> ${TEMP_LOG}
    #moving file to /complete/ dir
    echo "moving file to /complete/ dir" >> ${TEMP_LOG}
    cd ${TEMP_DIR} && mv ${INCRON_FILE_NAME} ${UPLOADED_DIR}
    res2log
    breakline
    #removing 6+ hours old uploaded files in ${UPLOADED_DIR}
    echo "removing 6+ hours old uploaded files in ${UPLOADED_DIR}, listed below"  >> ${TEMP_LOG}
    find ${UPLOADED_DIR} -type f -mmin +360  -print >> ${TEMP_LOG} -delete
    res2log
    breakline
    #setting filenames variable
    KEY_FILE_NAME=${INCRON_FILE_NAME}
    ENC_FILE_NAME=$(echo "${KEY_FILE_NAME}" | sed s'/\.otp.key$/.enc.file/')
    DEC_FILE_NAME=$(echo "${KEY_FILE_NAME}" | sed s'/\.otp.key$/.tar.gz/')
    #checking encrypted file integrity, and get one-time password from it
    get-passwd
    #looking for ENC_FILE_NAME
    cd  ${TEMP_DIR}  && ls | grep -q ${ENC_FILE_NAME}
    FILE_REP=$(echo "$?")
        if [ ${FILE_REP} = 0 ]
        then
            echo "encrypted file for key found SUCCESS" >> ${TEMP_LOG}
            ###
            ###
            ###
        else
            REPORT="encrypted file for keyfile not found ERROR"
            echo "${REPORT}" >> ${TEMP_LOG}
            breakline
            mailto
            exit
        fi
else
    echo "${INCRON_FILE_NAME}"  | grep -q .enc.file
    FILE_EXT_CHK=$(echo "$?")
        if [ ${FILE_EXT_CHK} = 0 ]
        then
            #checking uploaded file extension, and send it to log
            FILE_EXT_CHK="file.ext is .enc.file SUCCESS"
            echo "${FILE_EXT_CHK}"  >> ${TEMP_LOG}
            breakline
            #setting filenames variable
            ENC_FILE_NAME=${INCRON_FILE_NAME}
            KEY_FILE_NAME=$(echo "${ENC_FILE_NAME}" | sed s'/\.enc.file$/.otp.key/')
            DEC_FILE_NAME=$(echo "${ENC_FILE_NAME}" | sed s'/\.enc.file$/.tar.gz/')
            #looking for keyfile in ${UPLOADED_DIR}
            cd  ${UPLOADED_DIR} && ls | grep -q ${KEY_FILE_NAME}
            FILE_REP=$(echo "$?")
                if [ ${FILE_REP} = 0 ]
                then
                    REPORT="keyfile for encrypted file found SUCCESS"
                    echo "${REPORT}"  >> ${TEMP_LOG}
                    breakline
                    #checking encrypted file integrity, and get one-time password from it
                    get-passwd
                    ###
                    ###
                    ###
                else
                    REPORT="keyfile for encrypted file not found ERROR"
                    echo "${REPORT}" >> ${TEMP_LOG}
                    breakline
                    mailto
                    exit
                fi
        else
            FILE_EXT_CHK="file.ext is NOT .otp.key or .enc.file"
            echo "${FILE_EXT_CHK}"  >> ${TEMP_LOG}
            REPORT="bullshit uploaded to ${TEMP_DIR}, check ftp logs"
            echo "removing the bullshit file  ${INCRON_FILE_NAME}" >> ${TEMP_LOG}
            cd ${TEMP_DIR} && rm "${INCRON_FILE_NAME}"
            res2log
            breakline
            tail -n 20 ${FTP_LOG} >> ${TEMP_LOG}
            mailto
            exit
        fi
fi
#decrypt .enc.file
decrypt
#check integrity of decrypted compressed file
gz-test
#get DB filename, and send it to log
get-db-name
#uncompress file
uncompress
#rm ${DEC_FILE_NAME}
rm-decrypted
#add database to repo
db2repo
