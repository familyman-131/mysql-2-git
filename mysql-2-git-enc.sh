#!/bin/bash
###################################################
source /full/path/to/db-to-repo-serv-enc-iv.conf
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
            # mailto
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
                    # mailto
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
