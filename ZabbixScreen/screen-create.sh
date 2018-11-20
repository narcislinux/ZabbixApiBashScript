#!/bin/bash
##Author: Narges Ahmadi (NarcisLinux)  Email:n.sedigheh.ahmadi@gmail.com
##Vertion 1
##
##This screen should add screen. 
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

    vertion() {
        basename $0
    }

    error() {
        sleep 1
    }

    trapper() {

                for i in $1
                do
                    echo $i
                done
        }

    gethostlist() {
    #FUN gethostlist: Api request to zabbix and get HostGroup Host list.
curl --data-binary "{\"jsonrpc\": \"2.0\",\"method\": \"host.get\",\"params\": {\"output\": [\"host\"],\"groupids\": [\"$1\"]},\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 2}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null | jq -r .result[].host


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
		 \"graphids\": [$1]
	},
\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null|jq .
	  }

    createscreenitem (){
    #FUN createscreenitem: Create xml <screen_item>.
    #FUN createscreenitem:Example: getscreenitem $width $height $X $Y $Graphname $HostName $FinenameNewScreenXml
    #SCAFFOLD: #echo $1 $2 $3 $4 $5 $6 $7

    echo "             <screen_item>
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
    #SCAFFOLD:   cat "$FinenameNewScreenXml"

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

    updatescreenname() {
    #FUN updatescreenname:Api request to zabbix and update Screen name.
    curl --data-binary "{
    \"jsonrpc\": \"2.0\",
	\"method\": \"screen.update\",
	\"params\": {
		 \"screenid\": \"$1\",
		 \"name\": \"$2\"
	},
\"auth\":\""${AUTH_TOKEN}"\" ,\"id\": 1}" -H 'content-type:application/json-rpc;'  $API  2> /dev/null  |jq .
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

    analysescreen(){

        ArrayNewScreenitem=(`cat $2 | jq -r ".result[] | select (.screenid |contains(\"$1\" )) | \"\(.resourcetype),\(.resourceid),\(.y),\(.x)\" " | tr  '\n' ' '`)
        #SCAFFOLD:   echo ${ArrayNewScreenitem[@]}


            for i in ${ArrayNewScreenitem[@]} ;do NewScreenitemIDs="$NewScreenitemIDs,\"`echo $i|cut -d',' -f 2`\"" ; NewScreenitemIDs=`echo $NewScreenitemIDs |sed 's/^,//'` ;done ##CODE COMMENT: get just screenids for API file
            #SCAFFOLD:        echo $NewScreenitemIDs

            getgraphitem   $NewScreenitemIDs  >  $FilenameGraphListAll ##CODE COMMENT:  get all graphs in screen

            for i in  ${ArrayNewScreenitem[@]}  ##CODE COMMENT:  Analyse screen's items
            do
                Resourcetype=`echo $i | cut -d',' -f 1`
                Resourceid=`echo $i | cut -d',' -f 2`
                #SCAFFOLD: # echo "Resourceid   $Resourceid :"

                #OLD VERTION CODE:getgraphitem   $Resourceid | jq -r '.result[] | "\(.groups[].name),\(.name)" ' >  $FilenameGraphList
                GraphInfo=`cat $FilenameGraphListAll | jq -r ".result[] | select (.graphid |contains(\"$Resourceid\")) | \"\(.name)\" "`
                GraphName=`echo $GraphInfo | cut -d',' -f 2`
                GraphX=`echo $i | cut -d',' -f 4`
                GraphY=`echo $i | cut -d',' -f 3`
                #SCAFFOLD: cat $FilenameGraphList
                echo $GraphY $GraphX $GraphName
            done
        #SCRIPTING MESSAGE: echo "$MessageName: Screen $i"

         }


#############Variables#############
MessageName="SCRIPT `basename $0`"
#NewScreenName         //assigned value in code
#NewScreenID           //assigned value in code
NewScreenIDs=""
NewScreenitemIDs=""
#HostsNumber           //assigned value in code
#ArrayNewScreen        //assigned value in code
#ArrayNewScreenitem    //assigned value in code
#Resourcetype          //assigned value in code
#Resourceid            //assigned value in code
#ArrayGraphlist        //assigned value in code
#ArrayScreenCode       //assigned value in code

FilenameScreenList="/tmp/FDI-screen-list"
FilenameScreenItemList="/tmp/FDI-screen-item-list"
FilenameGraphListAll="/tmp/FDI-graph-list-all"
FilenameGraphList="/tmp/FDI-graph-list"
FinenameNewScreenXml="/tmp/New-Screen.xml"
FinenameNewScreenAnalyse="/tmp/New-Screen-analyse.xml"
FilenameHostsList="/tmp/FDI-hosts-list"

#############Trap#############
TrapFileList=("$FilenameScreenList" "$FilenameScreenItemList" "$FilenameGraphListAll" "$FilenameGraphList" "$FinenameNewScreenXml" "$FinenameNewScreenAnalyse")
trapper ${TrapFileList[@]}


#--------------Primary code--------------#
#

getscreenlist > $FilenameScreenList  ##CODE COMMENT: get screens list
ArrayNewScreen=(`cat $FilenameScreenList | jq -r '.result[] | "\(.name)@\(.screenid)" '  |grep -i "^#" | tr  '\n' ' '  ` ) ##CODE COMMENT: filter screens list and get name,screenid
#SCAFFOLD:echo ${ArrayNewScreen[@]}

for i in ${ArrayNewScreen[@]} ;do NewScreenIDs="$NewScreenIDs,\"`echo $i|cut -d'@' -f 2`\"" ;NewScreenIDs=`echo $NewScreenIDs |sed 's/^,//'` ;done
#SCAFFOLD: echo $NewScreenIDs


getscreenitem  $NewScreenIDs > $FilenameScreenItemList  ##CODE COMMENT:  get all new screen items

     for i in  ${ArrayNewScreen[@]} ##CODE COMMENT:  Analyse and add New screens
     do

            #
            ##CODE COMMENT:  sampel name '#system-test'
            #
            NewScreenName=`echo $i | cut -d'@' -f 1`
            NewScreenID=`echo $i | cut -d'@' -f 2`
            #SCAFFOLD:echo "New screen is $i $NewScreenID $NewScreenName :"
            ScreenName=`echo $NewScreenName |cut -d':' -f1|cut -d'#' -f2`
            ScreenHostGroup=`echo $NewScreenName |cut -d':' -f2`
            gethostlist "$ScreenHostGroup"  > ./a ;head -n100 ./a > $FilenameHostsList; HostsNumber=`wc -l $FilenameHostsList|cut -d' ' -f1`
            updatescreenname $NewScreenID $ScreenName 1>/dev/null
            analysescreen  "$NewScreenID" "$FilenameScreenItemList" > $FinenameNewScreenAnalyse ##CODE COMMENT:  Analyse screen's items

            ColumNumber=`cat $FinenameNewScreenAnalyse |cut -d' ' -f2|sort|uniq|wc -l`
            RowNumber=` expr $(cat $FinenameNewScreenAnalyse |cut -d' ' -f1|sort|uniq|wc -l) \* $HostsNumber `
            echo $RowNumber $ColumNumber



echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<zabbix_export>
    <version>3.4</version>
    <date>2018-04-07T08:52:18Z</date>
    <screens>
        <screen>
            <name>$ScreenName</name>
            <hsize>$ColumNumber</hsize>
            <vsize>$RowNumber</vsize>
            <screen_items>" >  "$FinenameNewScreenXml"

#SCAFFOLD:      ArrayY=(`cat $FinenameNewScreenAnalyse | awk '{print $1}'|tr '\n' ' '`);echo ${ArrayY[@]}
#SCAFFOLD:      ArrayX=(`cat $FinenameNewScreenAnalyse | awk '{print $2}'|tr '\n' ' '`);echo ${ArrayX[@]}
#SCAFFOLD:      cat $FinenameNewScreenAnalyse|cut -d' ' -f2
        Y=0
        while read HostName
        do
            while read i
            do
                Ystep=`echo $i $FinenameNewScreenAnalyse | awk '{print $1}'`;Y=$(expr  "$Ystep" + "$Y" )
                X=`echo $i | awk '{print $2}'`
                GraphName=`echo $i |cut -d' ' -f3-`
                #SCAFFOLD:       echo $Ystep $X $Y $HostName  $GraphName
                createscreenitem '400' '100' $X $Y "$GraphName" "$HostName" "$FinenameNewScreenXml"
            done < $FinenameNewScreenAnalyse
            Y=`expr $Y + 1 `
        done < $FilenameHostsList


echo "            </screen_items>
        </screen>
    </screens>
</zabbix_export>" >>  "$FinenameNewScreenXml"



#SCAFFOLD:
cat $FinenameNewScreenXml >/tmp/a.xml
importscreen  $FinenameNewScreenXml



     done

#
#--------------End--------------#


