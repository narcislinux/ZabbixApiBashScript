#!/bin/bash
##Author: Narges Ahmadi (NarcisLinux)  Email:n.sedigheh.ahmadi@gmail.com
##Vertion 1
##
##Whit this script you gan get zabbix screen item information
##
#############Authentication#############
USER=''
#read  USER
PASS=''
#read -p "Password:" -s PASS

#ZABBIX_SERVER='zabbix.server.com'
#echo "API='http:///api_jsonrpc.php'"
API='http:///api_jsonrpc.php'


    authenticate() {
    #FUN authenticate: Authenticate with Zabbix API.
 echo `curl -s -H  'Content-Type: application/json-rpc' -d "{\"jsonrpc\": \"2.0\",\"method\":\"user.login\",\"params\":{\"user\":\""${USER}"\",\"password\":\""${PASS}"\"},\"auth\": null,\"id\":0}" $API`
  }

AUTH_TOKEN=`echo $(authenticate)|jq -r .result`
#echo $AUTH_TOKEN


#############Functions#############

    gethostlist() {
    #FUN gethostlist: Api request to zabbix and get HostGroup Host list.
curl --data-binary "{\"jsonrpc\": \"2.0\",\"method\": \"host.get\",\"params\": {\"output\": [\"host\"],\"groupids\": [\"${HostGroupID}\"]},\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 2}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null | jq .result[].host


      }

    getscreenlist() {
    #FUN getscreenlist:Api request to zabbix and get Screen names and IDs list.
    #FUN getscreenlist:Example:filter for output jq -r '.result[] | "\(.name),\(.screenid)" '
    #FUN getscreenlist:Example: getscreenlist [screenids]
    if [ -z $1 ]
    then
        screenids=""

    else
        screenids=",\"screenids\": \"$1\", \"selectScreenItems\": \"extend\""
     
    fi
    curl --data-binary "{
    \"jsonrpc\": \"2.0\",
	\"method\": \"screen.get\",
	\"params\": {
		 \"output\": [\"name\"]
		 $screenids
	},
\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null
	  }


    getscreenitem() {
    #FUN getscreenitem:Api request to zabbix and get Screen items info.
    curl --data-binary "{
    \"jsonrpc\": \"2.0\",
	\"method\": \"screenitem.get\",
	\"params\": {
		 \"output\": \"extend\",
		 \"screenids\": [$1]
	},
\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null  |jq .
	  }

    getgraphitem() {
    #FUN getgraphitem:Api request to zabbix and get Graph items info.
    curl --data-binary "{
    \"jsonrpc\": \"2.0\",
	\"method\": \"graph.get\",
	\"params\": {
		 \"output\": [\"name\"],
		 \"selectGroups\": [\"name\"],
		 \"graphids\": [$1]
	},
\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null|jq .
	  }
	                                                                                                            
    createscreenitem (){
    #FUN createscreenitem: Create xml <screen_item>.
    #FUN createscreenitem:Example: getscreenitem $width $height $X $Y $Graphname $HostName $FinenameNewScreenXml
    #SCAFFOLD: #echo $1 $2 $3 $4 $5 $6 $7

    echo "            <screen_item>
                        <resourcetype>0</resourcetype>
                        <width>$1</width>
                        <height>$2</height>
                        <x>$3</x>
                        <y>$4</y>
                        <colspan>1</colspan>
                        <rowspan>1</rowspan>
                        <elements>0</elements>
                        <valign>0</valign>
                        <halign>0</halign>
                        <style>0</style>
                        <url/>
                        <dynamic>0</dynamic>
                        <sort_triggers>0</sort_triggers>
                        <resource>
                            <name>$5</name>
                            <host>$6</host>
                        </resource>
                        <max_columns>3</max_columns>
                        <application/>
                  </screen_item>" >> "$7"

    }


    importscreen() {
    #FUN importscreen:import xml screen's template in zabbix
    #FUN importscreen:Example: importscreen  $FinenameNewScreenXml
    sed -i 's/"/\\"/g' "$1"
    sed -in ':a;$s/[\n\t]//g;N;ba'    "$1"
    #SCAFFOLD: #cat "$FinenameNewScreenXml"

    curl --data-binary "{

        \"jsonrpc\": \"2.0\",
        \"method\": \"configuration.import\",
        \"params\": {
            \"format\": \"xml\",
             \"rules\": {
                \"screens\": {
                            \"createMissing\": true,
                            \"updateExisting\": true
                    }
                } ,
            \"source\": \"$(cat "$1")\"
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
        #SCRIPTING MESSAGE: #echo "SCRIPT:FUN blacklist: $i removed from host list"
     done
     }


#############Variables#############
#NewScreenName            //assigned value in code
#NewScreenID              //assigned value in code
#NewScreenIDs          //assigned value in code
#ArrayNewScreen        //assigned value in code
#ArrayNewScreenitem    //assigned value in code
#Resourcetype          //assigned value in code
#Resourceid            //assigned value in code
#ArrayGraphlist        //assigned value in code


FilenameScreenList="/tmp/FDI-screen-list"
FilenameScreenItemList="/tmp/FDI-screen-item-list"
FilenameGraphListAll="/tmp/FDI-graph-list-all"
FilenameGraphList="/tmp/FDI-graph-list"
FinenameNewScreenXml="/tmp/New-Screen.xml"

#--------------Primary code--------------#

if [ -z "$1" ]
then
      ScreenList='#test' ##CODE COMMENT:  default value
else
      ScreenList=$1
fi


getscreenlist > $FilenameScreenList  ##CODE COMMENT: get screens list
ArrayNewScreen=(`cat $FilenameScreenList | jq -r '.result[] | "\(.name),\(.screenid)" '  |grep -i "^$ScreenList"| tr  '\n' ' '  ` ) ##CODE COMMENT: filter screens list and get name,screenid
#SCAFFOLD:  echo ${ArrayNewScreen[@]}

NewScreenIDs=`cat $FilenameScreenList | jq -r '.result[] | "\(.name),\"\(.screenid)\"," '  |grep -i "^$ScreenList" | cut -d',' -f 2|tr  '\n' ' '|sed 's/\ "/,"/g'`  ##CODE COMMENT: get just screenids for API file
#SCAFFOLD: echo $NewScreenIDs
getscreenitem  $NewScreenIDs > $FilenameScreenItemList  ##CODE COMMENT:  get all new screen items


     for i in  ${ArrayNewScreen[@]} ##CODE COMMENT:  Analyse and add New screens
     do
        NewScreenName=`echo $i | cut -d',' -f 1`
        NewScreenID=`echo $i | cut -d',' -f 2`
        #SCAFFOLD:        echo "New screen is $NewScreenID :"

        ArrayNewScreenitem=(`cat $FilenameScreenItemList | jq -r ".result[] | select (.screenid |contains(\"$NewScreenID\" )) | \"\(.resourcetype),\(.resourceid),\(.y),\(.x)\" " | tr  '\n' ' '`)

        #SCAFFOLD:        echo ${ArrayNewScreenitem[@]}

        NewScreenitemIDs=`cat $FilenameScreenItemList | jq -r '.result[] | "\"\(.resourceid)\""' |tr  '\n' ' '|sed 's/\ "/,"/g'`  ##CODE COMMENT: get just screenids for API file
        #SCAFFOLD:        echo $NewScreenitemIDs
        getgraphitem   $NewScreenitemIDs  >  $FilenameGraphListAll ##CODE COMMENT:  get all graphs in screen

        for i in  ${ArrayNewScreenitem[@]}  ##CODE COMMENT:  Analyse screen's items
        do
            Resourcetype=`echo $i | cut -d',' -f 1`
            Resourceid=`echo $i | cut -d',' -f 2`
            #SCAFFOLD: #echo "Resourceid   $Resourceid :"

            #OLD VERTION CODE:getgraphitem   $Resourceid | jq -r '.result[] | "\(.groups[].name),\(.name)" ' >  $FilenameGraphList
            #OLD VERTION CODE:GraphInfo=`cat $FilenameGraphListAll | jq -r ".result[] | select (.graphid |contains(\"$Resourceid\")) | \"\(.name),\(.groups[].name)\" "`
            GraphName=`cat $FilenameGraphListAll | jq -r ".result[] | select (.graphid |contains(\"$Resourceid\")) | \"\(.name)\" "`
            GraphHostGroup=`cat $FilenameGraphListAll | jq -r ".result[] | select (.graphid |contains(\"$Resourceid\")) | \"\(.groups[].name)\" "`
            GraphX=`echo $i | cut -d',' -f 4`
            GraphY=`echo $i | cut -d',' -f 3`
            #SCAFFOLD: cat $FilenameGraphList
            echo "Resourcetype[$Resourcetype] Resourceid[$Resourceid] y[$GraphY] x[$GraphX]   GraphName[$GraphName]    GraphHostGroup[$GraphHostGroup]"
        done
        #SCRIPTING MESSAGE: #echo "SCRIPT: Screen $i"
     done

#--------------End--------------#


