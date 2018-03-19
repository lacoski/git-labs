#!/bin/bash
### Server Active check
WEBSERVER_CHECK=127.0.0.1
STATUS_CODE=`curl -sL -w "%{http_code}\\n" "$WEBSERVER_CHECK" -o /dev/null`

echo $STATUS_CODE

if [ $STATUS_CODE == 200 ]
then
        echo "true"
        exit 0
elif [ $STATUS_CODE == 000 ]
then
        echo "Code fail!!"
        exit 1
else
        echo "not known"
        exit 1
fi

echo "fail all"
exit 1
