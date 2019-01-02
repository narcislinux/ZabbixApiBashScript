#!/bin/bash


#Zabbix Authentication
USER=''
#echo -n "Enter your api user:"
#read USER
PASS='' 
#read -p "Password:" -s PASS
#ZABBIX_SERVER='zabbix.server.com'
#echo "API='http:///zabbix/api_jsonrpc.php'"
API=''

# Authenticate with Zabbix API
authenticate() {
echo `curl -s -H 'Content-Type: application/json-rpc' -d "{\"jsonrpc\": \"2.0\",\"method\":\"user.login\",\"params\":{\"user\":\""${USER}"\",\"password\":\""${PASS}"\"},\"auth\": null,\"id\":0}" $API`
}
AUTH_TOKEN=`echo $(authenticate)|jq -r .result`
#AUTH_TOKEN='?vKLt$%QLj7n^qsgcC4ejESYdUcTWR'
#echo $AUTH_TOKEN



gethostlist() {

curl --data-binary "{\"jsonrpc\": \"2.0\",\"method\": \"host.get\",\"params\": {\"output\": [\"host\"],\"groupids\": [\"${HostID}\"]},\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 2}" -H 'content-type:application/json-rpc;' $API 2> /dev/null | jq .result[].host
}

      gettriggerlist() {


curl --data-binary " 
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"trigger.get\",
    \"params\": {
        \"output\": \"extend\",
        \"filter\": {
            \"host\": [
                \""$HostName"\"
            ]
        }
    },
    \"auth\": \""${AUTH_TOKEN}"\",
    \"id\": 2
}

" -H 'content-type:application/json-rpc;'  $API  2> /dev/null | jq .


      }

      gethostid() {


curl --data-binary " 
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": \"hostid\",
        \"filter\": {
            \"host\": [
                \""$HostName"\"
            ]
        }
    },
    \"auth\": \""${AUTH_TOKEN}"\",
    \"id\": 2
}

" -H 'content-type:application/json-rpc;'  $API  2> /dev/null | jq .


      }

      gethostip() {

curl --data-binary " 
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostinterface.get\",
    \"params\": {
        \"output\": \"extend\",
        \"hostids\": \"$HostID\"
    },
    \"auth\": \""${AUTH_TOKEN}"\",
    \"id\": 1
}

" -H 'content-type:application/json-rpc;'  $API  2> /dev/null | jq .

      }


FilenameNewMap="./New-map.xml"
FilenameZabbixXmlMap="./map.xml"
FilenameSelements="/tmp/map-selements"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<zabbix_export>
    <version>4.0</version>
    <date>2019-01-02T05:34:52Z</date>" > $FilenameNewMap


xmllint --xpath '//images' "$FilenameZabbixXmlMap" >> $FilenameNewMap
sleep 1
read -p "Map name:" MapName
sleep 1

echo "
<maps>
<map>
<name>$MapName</name>
<width>2000</width>
<height>2280</height>
<label_type>4</label_type>
<label_location>0</label_location>
<highlight>1</highlight>
<expandproblem>0</expandproblem>
<markelements>1</markelements>
<show_unack>1</show_unack>
<severity_min>0</severity_min>
<grid_size>20</grid_size>
<grid_show>1</grid_show>
<grid_align>1</grid_align>
<label_format>0</label_format>
<label_type_host>2</label_type_host>
<label_type_hostgroup>2</label_type_hostgroup>
<label_type_trigger>2</label_type_trigger>
<label_type_map>2</label_type_map>
<label_type_image>2</label_type_image>
<label_string_host/>
<label_string_hostgroup/>
<label_string_trigger/>
<label_string_map/>
<label_string_image/>
<expand_macros>1</expand_macros>
<background/>
<iconmap/>
<urls/>
" >> $FilenameNewMap



xmllint --xpath '//selements' "$FilenameZabbixXmlMap" > "$FilenameSelements"
i=0
while read line;
do

i=`expr $i + 1 `

if [ $(echo $line|grep "<selement>" >/dev/null 2>&1 ; echo $?) = 0 ]
then
echo "Element $i start "
echo " <selement>" >> $FilenameNewMap
elif [ $(echo $line|grep "<host>" >/dev/null 2>&1 ; echo $?) = 0 ]
then 

	HostName=`echo " $line"|sed 's/<\/host>//'|sed 's/<host>//'|awk '{print $1}'`
	echo " $line" >> $FilenameNewMap 

elif [ $(echo $line|grep "<urls/>" >/dev/null 2>&1 ; echo $?) = 0 ]
then

echo "<urls>
		 <url>
		 <name>$HostName  </name>
		 <url>http://172.20.8.32/zabbix/zabbix.php?action=dashboard.view&ddreset=1</url>
		 </url>
 </urls>" >> $FilenameNewMap

else
echo " $line" >> $FilenameNewMap 
fi



done < $FilenameSelements

echo "</selements>" >> $FilenameNewMap
xmllint --xpath '//shapes' "$FilenameZabbixXmlMap" >> $FilenameNewMap
echo "            <lines/>" >> $FilenameNewMap
xmllint --xpath '//links'  "$FilenameZabbixXmlMap" >> $FilenameNewMap

echo "
        </map>
    </maps>
</zabbix_export>" >> $FilenameNewMap


