
#!/bin/bash
##Author: Narges Ahmadi (NarcisLinux)  Email:n.sedigheh.ahmadi@gmail.com
##Vertion 1
##
##sync Zabbix's hosts with Cacti
##
#############Authentication#############
USER=''
#read  USER
PASS=''
#read -p "Password:" -s PASS

#ZABBIX_SERVER='zabbix.server.com'
#For example "API='http://192.168.0.100/zabbix/api_jsonrpc.php'"
API='http:///api_jsonrpc.php'



    authenticate() {
    #FUN authenticate: Authenticate with Zabbix API.
 echo `curl -s -H  'Content-Type: application/json-rpc' -d "{\"jsonrpc\": \"2.0\",\"method\":\"user.login\",\"params\":{\"user\":\""${USER}"\",\"password\":\""${PASS}"\"},\"auth\": null,\"id\":0}" $API`
  }

AUTH_TOKEN=`echo $(authenticate)|jq -r .result`
#echo $AUTH_TOKEN


#############Functions#############

    gethostlistofgroup() {
    #FUN gethostlist: Api request to zabbix and get HostGroup Host list.
curl --data-binary "
	{
		\"jsonrpc\": \"2.0\",
		\"method\": \"host.get\",
		\"params\": {
			\"output\": \"extend\",
			\"groupids\": [\"$1\"],
            \"selectInterfaces\": \"extend\",
		    \"selectMacros\": \"extend\",
		    \"filter\": {
        		    \"status\": [
               			 \"0\"
		            ]
		    		}
			},
		\"auth\":\""${AUTH_TOKEN}"\"
		,\"id\": 2
		}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null


      }



     gethostiplist() {
       #     curl --data-binary "{\"jsonrpc\": \"2.0\",\"method\": \"hostinterface.get\",\"params\": {\"output\": [\"ip\"],\"selectParentTemplates\": [\"templateid\",\"name\"]},\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;' $API  2> /dev/null | jq .result[].ip
curl --data-binary "{\"jsonrpc\": \"2.0\",\"method\": \"hostinterface.get\",\"params\": {\"output\": \"extend\",\"hostids\": \"100\"},\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;' $API  2> /dev/null | jq .result[].ip

      }

      gethostgrouplist() {

curl --data-binary "{

	\"jsonrpc\": \"2.0\",
	\"method\": \"hostgroup.get\",
	\"params\": {
        \"output\": [\"groupid\",\"name\"]

},

\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null
     }


     blacklist()  {
     #FUN blacklist:Remove Blacklist  hosts from Host list and screen
     #FUN blacklist:Example: blacklist ${Array[@]} $FilenameHosts

     FilenameTMP="/tmp/FDI-zabbix-screen-tmp"
     for i in  $1
     do
        grep -iv $i "$2" > "$FilenameTMP"
        cat "$FilenameTMP"  > "$2"
        #SCRIPTING MESSAGE: #echo "MessageName:FUN blacklist: $i removed from host list"
     done
     }



#############Variables#############
#GroupID                 //assigned value in code
#GroupName               //assigned value in code
#HostNumber              //assigned value in code
#HostName                //assigned value in code
CactiIP=''
SnmpMacro=\"{\$SNMP_COMMUNITY}\"
#ArrayGroupList         //assigned value in code
#ArrayInterfaceList     //assigned value in code

FilenameGroupqList="/tmp/Zabbix-host-group-list"
FilenameHostListONGroup="/tmp/Zabbix-hosts-on-group-list"
FileNameCactiTemplateList="/tmp/cacti-hosts-template"
CliPath='/var/www/cacti/cli/'

#--------------Primary code--------------#

ArrayGroupList=("test")
gethostgrouplist > $FilenameGroupqList

ssh root@"$CactiIP"		php $CliPath/add_device.php --list-host-templates > $FileNameCactiTemplateList


for GroupName in "${ArrayGroupList[@]}"
do
    GroupID=`cat  $FilenameGroupqList |jq -r ".result[] | select(.name == \"$GroupName\")| .groupid "`
    gethostlistofgroup $GroupID > $FilenameHostListONGroup
    HostNumber=`cat $FilenameHostListONGroup |jq -r ".result[] | .hostid" |wc -l` ; echo $HostNumber
    Template=`cat $FileNameCactiTemplateList |awk '{print $1" "$2}'|grep " $GroupName$"|cut -d" " -f1`
    export Template
    echo "++++++++++++++++++++++++++++++ Group $GroupName $Template :"

    for((i=0;i<$HostNumber;i++))
    do
        #cat $FilenameHostListONGroup |jq -r ".result[$i] | .hostid"
        HostName=`cat $FilenameHostListONGroup |jq -r ".result[$i] | .host"`
        HostID=`cat $FilenameHostListONGroup |jq -r ".result[$i] | .hostid"`
        ArrayInterfaceList=(`cat $FilenameHostListONGroup|jq  .result[$i].interfaces[].interfaceid |tr '\n' ' ' `)
        Macrosvalue=`cat $FilenameHostListONGroup|jq -r ".result[$i].macros[] | select(.macro == $SnmpMacro )|.value"`

        if [ ! -z "$Macrosvalue" ]
        then

            for j in ${ArrayInterfaceList[@]}
            do
                IP=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .ip "`
                DNS=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .dns" `
                Type=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .type" `
    ## Host interface type
    #        Possible values are:
    #           1 - agent;
    #           2 - SNMP;
    #           3 - IPMI;
    #           4 - JMX.



				if [ ! "$IP" == "" ]
				then
		    		if [ ! -z $DNS ]
	                then
	                ssh root@"$CactiIP"	php $CliPath/add_device.php --description="$HostName-$DNS" --ip="$IP" --template="$Template"  --avail="ping" --ping_method="icmp"
	                else
	                ssh root@"$CactiIP"		php $CliPath/add_device.php --description="$HostName" --ip="$IP" --template="$Template"  --avail="ping" --ping_method="icmp"
	                fi
				else
				ssh root@"$CactiIP"		php $CliPath/add_device.php --description="$HostName" --ip="$DNS" --template="$Template"  --avail="ping" --ping_method="icmp"
				fi



            done

        elif [  -z "$Macrosvalue" ]
        then
            for j in ${ArrayInterfaceList[@]}
            do
                IP=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .ip "`
                DNS=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .dns" `
                Type=`cat $FilenameHostListONGroup |jq -r  ".result[$i].interfaces[] | select(.interfaceid == $j) | .type" `
    ## Host interface type
    #        Possible values are:
    #           1 - agent;
    #           2 - SNMP;
    #           3 - IPMI;
    #           4 - JMX.


				if [ ! "$IP" == "" ];then

				    if [ ! -z $DNS ]
	                then

	                ssh root@"$CactiIP"		php $CliPath/add_device.php --description="$HostName-$DNS" --ip=$IP --template="$Template"  --avail=pingsnmp --ping_method=icmp --version=2 --community="$Macrosvalue"
	                else
	                ssh root@"$CactiIP"		php $CliPath/add_device.php --description="$HostName" --ip=$IP --template="$Template"  --avail=pingsnmp --ping_method=icmp --version=2 --community="$Macrosvalue"
	                fi
				else
				ssh root@"$CactiIP"		php $CliPath/add_device.php --description="$HostName" --ip="$DNS" --template="$Template"  --avail="pingsnmp" --ping_method="icmp" --version="2" --community="$Macrosvalue"

				fi


            done


        else

            echo "Error $HostName"

        fi


    done



#
#
done

#--------------end--------------#
