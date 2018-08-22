#!/bin/bash

url_encode() {
	[ $# -lt 1 ] && { return; }

	encodedurl="$1";

	# make sure hexdump exists, if not, just give back the url
	[ ! -x "/usr/bin/hexdump" ] && { return; }

	encodedurl=`
		echo $encodedurl | hexdump -v -e '1/1 "%02x\t"' -e '1/1 "%_c\n"' |
		LANG=C awk '
			$1 == "20"			{ printf("%s",   "+"); next } # space becomes plus
			$1 ~  /0[adAD]/			{                      next } # strip newlines
			$2 ~  /^[a-zA-Z0-9.*()\/-]$/	{ printf("%s",   $2);  next } # pass through what we can
							{ printf("%%%s", $1)        } # take hex value of everything else
		'`
	echo $encodedurl
}


baseurl="https://api.five9.com/ivr/1"
while getopts d:c: option
do
	case "${option}"
		in
		d) domain_name=${OPTARG};;
		c) campaign_name=${OPTARG};;
	esac
done

echo "VisualIVR VisualIVR VisualIVR VisualIVR Visual IVRVisualIVR VisualIVR "
url="$baseurl/domains/$( url_encode $domain_name )/campaigns?name=$( url_encode $campaign_name )"
echo $url

result=$(curl -X GET -i -H "Content-Type: application/json" $url) 
re="\"id\"\:(\d+)\,\"domainId\"\:(\d+)\,\"isVisualIVREnabled\"\:(true|false)\,\"isChatEnabled\"\:(true|false)\,\"isEmailEnabled\"\:(true|false)"
if [[ $result =~ $re ]] 
then 
	campaign=${BASH_REMATCH[1]}
	domain=${BASH_REMATCH[2]}
	isVisualIVREnable=${BASH_REMATCH[3]}
	isChatEnabled=${BASH_REMATCH[4]}
	isEmailEnabled=${BASH_REMATCH[5]}

else
	echo $result
	echo "Exiting..."
	exit
fi

result=$(curl -X GET -i -H "Content-Type: application/json" $baseurl/campaigns/$campaign/email/create_session)
echo $result
re="\"id\"\:\"([^\"]+)\""
if [[ $result =~ $re ]] 
then 
	session=${BASH_REMATCH[1]}
	result=$(curl -X GET -i -H "Content-Type: application/json" -d "token=123&userid=789" $baseurl/sessions/$session)
	echo $result
	
	isFinal="false"
	while [[ $isFinal == "false" ]]; do
		re="\"stage\"\:([0-9]+)\,\"scriptId\"\:\"([^\"]+)\",\"moduleId\"\:\"([^\"]+)\".+\"isFinal\"\:(true|false)"
		if [[ $result =~ $re ]] 
		then 
			stage=${BASH_REMATCH[1]}
			scriptId=${BASH_REMATCH[2]}
			moduleId=${BASH_REMATCH[3]}
			isFinal=${BASH_REMATCH[4]}

			data="{\"name\":\"userAnswer\",\"moduleId\":\"$moduleId\",\"scriptId\":\"$scriptId\",\"branchId\":null,\"args\":{}}"
			echo $data
			result=$(curl -X POST -i -H "Content-Type: application/json" -d "$data" $baseurl/sessions/$session/stages/$stage/action)
			echo $result
		fi
	done
	result=$(curl -X DELETE -i -H "Content-Type: application/json" -d "token=123&userid=789" $baseurl/sessions/$session)
fi
exit

