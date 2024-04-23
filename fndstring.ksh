#!/usr/bin/ksh
#
#       Code: Paul Ohashi, Quest Software
#       Date: April 7, 2003
#
#       fndstring recursively searches directories for
#       files (text and binary) containing a string.
#
#       Once upon a time in a support job long ago, I created this script
#       to help me find strings in configuration files, text files and even
#       binary files that I would receive from customers as I was trying to
#       resolve/close out their support tickets.  I still use this script
#       today to help with my own investigations.
#

theList='fndstring.lst'
[[ -f ${theList} ]] && rm -f ${theList}

theLog='fndstring.log'
[[ -f ${theLog} ]] && rm -f ${theLog}

set -A foundStringIn
set -A timeBar
filesSearched=1
bars=0
pctDone=0
numFound=0
cnt=0
#theSmile="\\001"
theSmile="|"

clear
print "\n\n\n\tCollecting information...\n"
find . -type f -print > ${theList}
lastFile=`tail -1 ${theList}`
numFilesToCheck=`wc -l ${theList}|awk '{print $1}'`
numOfTimeBars = ${numFilesToCheck} / 10

function theDisplay {
        clear
        if [[ ${cnt} -ge ${numOfTimeBars} || ${pctDone} -eq 100 ]] ; then
           cnt=0
           [[ ${pctDone} -lt 100 ]] && (( pctDone = ${pctDone} + 10 ))
           (( bars = ${bars} + 1 ))
           #timeBar[${bars}]='|'
           timeBar[${bars}]=${theSmile}
        fi
        print -n "\n\n\n\n\tLooking for \"${theString}\" in: ${theFile}\n\n\tStatus ${pctDone}% complete: "
        #print -n "\\033[0;44m"
        for i in ${timeBar[*]} ; do
           print -n "${timeBar[${bars}]}"
        done
        #print -n "\\033[0;38m\n\n\tFiles searched: ${filesSearched} out of: ${numFilesToCheck}\n\n"
        print -n "\n\n\tFiles searched: ${filesSearched} out of: ${numFilesToCheck}\n\n"
        [[ ${numFound} -gt 0 ]] && print -n "\tFound \"${theString}\" in ${numFound} file(s)\n\n"
       (( cnt = ${cnt} + 1 ))
}

clear
print -n "\n\n\n\t"
read theString?"Enter search string: "

cat ${theList}|while read lineIn ; do
 if [[ ${lineIn} = "./${theList}" || ${lineIn} = "./${theLog}" ]] ; then
    continue
 else
    theFile=${lineIn}
    (( filesSearched = ${filesSearched} + 1 ))
    theDisplay
    strings ${theFile}|grep -il "${theString}"|grep -v grep 2> /dev/null
    if [[ $? = 0 ]] ; then
       foundStringIn[${numFound}]=`echo ${theFile}|sed 's/\.\///g'`
       print "Found \"${theString}\" in: ${foundStringIn[${numFound}]}" >> ${theLog}
       (( numFound = ${numFound} + 1 ))
    fi
 fi
done
rm -f ${theList}
[[ -s ${theLog} ]] && print "\n\t*** View ${theLog} for a list of files containing \"${theString}\". ***\n"
