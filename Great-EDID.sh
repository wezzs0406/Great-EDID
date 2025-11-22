#!/bin/bash

cat <<EEF
====================================================================
   ___   ___   ___     _     _____         ___   ___    ___   ___
  / __| | _ \ | __|   /_\   |_   _|  ___  | __| |   \  |_ _| |   \
  
 | (_ | |   / | _|   / _ \    | |   |___| | _|  | |) |  | |  | |) |
  \___| |_|_\ |___| /_/ \_\   |_|         |___| |___/  |___| |___/

====================================================================
EEF

currentDir="$(cd $(dirname -- $0) && pwd)"
systemLanguage=($(locale | grep LANG | sed s/'LANG='// | tr -d '"' | cut -d "." -f 1))
is_applesilicon=$([[ "$(uname -m)" == "arm64" ]] && echo true || echo false)

langDisplay="Display"
langMonitors="Monitors"
langIndex="Index"
langVendorID="VendorID"
langProductID="ProductID"
langMonitorName="MonitorName"
langChooseDis="Choose the display"
langInputChoice="Enter your choice"
langEnterError="Enter error, bye"
langBackingUp="Backing up..."
langEnabled="EDID injected successfully, please reboot."
langDisabled="Disabled, restart takes effect"
langEnabledLog="No HIDPI configured, only EDID injected."

langChooseIcon="Display Icon"
langNotChange="Do not change"

langInjectEDID="(%d) Inject EDID"
langDisableHIDPI="(%d) Disable EDID/reset settings"

langDisableOpt1="(1) Remove EDID for this monitor"
langDisableOpt2="(2) Reset all settings to macOS default"

langNoMonitFound="No monitors were found. Exiting..."
langMonitVIDPID="Your monitor VID:PID:"

if [[ "${systemLanguage}" == "zh_CN" ]]; then
    langDisplay="显示器"
    langMonitors="显示器"
    langIndex="序号"
    langVendorID="供应商ID"
    langProductID="产品ID"
    langMonitorName="显示器名称"
    langChooseDis="选择显示器"
    langInputChoice="输入你的选择"
    langEnterError="输入错误，再见了您嘞！"
    langBackingUp="正在备份(怎么还原请看说明)..."
    langEnabled="EDID注入成功，重启生效"
    langDisabled="关闭成功，重启生效"
    langEnabledLog="未配置HIDPI，仅注入EDID"

    langChooseIcon="选择显示器ICON"
    langNotChange="保持原样"

    langInjectEDID="(%d) 注入EDID"
    langDisableHIDPI="(%d) 关闭EDID/重置设置"

    langDisableOpt1="(1) 移除该显示器的EDID配置"
    langDisableOpt2="(2) 还原所有设置至 macOS 默认"

    langNoMonitFound="没有找到监视器。 退出..."
    langMonitVIDPID="您的显示器 供应商ID:产品ID:"
elif [[ "${systemLanguage}" == "uk_UA" ]]; then
    langDisplay="Монітор"
    langMonitors="Монітор"
    langIndex="Номер"
    langVendorID="ID Виробника"
    langProductID="ID Продукту"
    langMonitorName="Імʼя пристрою"
    langChooseDis="Вибери монітор"
    langInputChoice="Введи свій вибір"
    langEnterError="Помилка вводу, бувай..."
    langBackingUp="Зберігаю..."
    langEnabled="EDID успішно інжектовано! Перезавантаж компʼютер."
    langDisabled="Вимкнено. Перезавантаж компʼютер."
    langEnabledLog="HIDPI не налаштовано, лише EDID інжектовано"

    langChooseIcon="Вибери піктограму"
    langNotChange="Не змінювати піктограму"

    langInjectEDID="(%d) Інжектувати EDID"
    langDisableHIDPI="(%d) Вимкнути EDID/скинути налаштування"

    langDisableOpt1="(1) Видалити EDID для цього монітора"
    langDisableOpt2="(2) Відновити заводські налаштування macOS"

    langNoMonitFound="Моніторів не знайдено. Завершую роботу..."
    langMonitVIDPID="ID Виробника:ID пристрою твого монітора:"
fi

function get_edid() {
    local index=0
    local selection=0

    gDisplayInf=($(ioreg -lw0 | grep -i "IODisplayEDID" | sed -e "/[^<]*</s///" -e "s/\>//"))

    if [[ "${#gDisplayInf[@]}" -ge 2 ]]; then
        echo ""
        echo "                      "${langMonitors}"                      "
        echo "--------------------------------------------------------"
        echo "   "${langIndex}"   |   "${langVendorID}"   |   "${langProductID}"   |   "${langMonitorName}"   "
        echo "--------------------------------------------------------"

        for display in "${gDisplayInf[@]}"; do
            let index++
            MonitorName=("$(echo ${display:190:24} | xxd -p -r)")
            VendorID=${display:16:4}
            ProductID=${display:22:2}${display:20:2}

            if [[ ${VendorID} == 0610 ]]; then
                MonitorName="Apple Display"
            fi
            if [[ ${VendorID} == 1e6d ]]; then
                MonitorName="LG Display"
            fi

            printf "    %d    |    ${VendorID}    |     ${ProductID}    |  ${MonitorName}\n" ${index}
        done

        echo "--------------------------------------------------------"
        read -p "${langChooseDis}: " selection
        case $selection in
        [[:digit:]]*)
            if ((selection < 1 || selection > index)); then
                echo "${langEnterError}"
                exit 1
            fi
            let selection-=1
            gMonitor=${gDisplayInf[$selection]}
            ;;
        *)
            echo "${langEnterError}"
            exit 1
            ;;
        esac
    else
        gMonitor=${gDisplayInf}
    fi

    EDID=${gMonitor}
    VendorID=$((0x${gMonitor:16:4}))
    ProductID=$((0x${gMonitor:22:2}${gMonitor:20:2}))
    Vid=($(printf '%x\n' ${VendorID}))
    Pid=($(printf '%x\n' ${ProductID}))
}

function get_vidpid_applesilicon() {
    local index=0
    local prodnamesindex=0
    local selection=0
    local appleDisplClass='AppleCLCD2'

    local vends=($(ioreg -l | grep "DisplayAttributes" | sed -n 's/.*"LegacyManufacturerID"=\([0-9]*\).*/\1/p'))
    local prods=($(ioreg -l | grep "DisplayAttributes" | sed -n 's/.*"ProductID"=\([0-9]*\).*/\1/p'))

    set -o noglob
    IFS=$'\n' prodnames=($(ioreg -l | grep "DisplayAttributes" | sed -n 's/.*"ProductName"="\([^"]*\)".*/\1/p'))
    set +o noglob

    if [[ "${#prods[@]}" -ge 2 ]]; then
        echo ""
        echo "                      "${langMonitors}"                      "
        echo "------------------------------------------------------------"
        echo "   "${langIndex}"   |   "${langVendorID}"   |   "${langProductID}"   |   "${langMonitorName}"  "
        echo "------------------------------------------------------------"

        for prod in "${prods[@]}"; do
            MonitorName=${prodnames[$prodnamesindex]}
            VendorID=$(printf "%04x" ${vends[$index]})
            ProductID=$(printf "%04x" ${prods[$index]})

            let index++
            let prodnamesindex++

            if [[ ${VendorID} == 0610 ]]; then
                MonitorName="Apple Display"
                let prodnamesindex--
            fi
            if [[ ${VendorID} == 1e6d ]]; then
                MonitorName="LG Display"
            fi

            printf "    %-3d    |     ${VendorID}     |  %-12s |  ${MonitorName}\n" ${index} ${ProductID}
        done

        echo "------------------------------------------------------------"
        read -p "${langChooseDis}: " selection
        case $selection in
        [[:digit:]]*)
            if ((selection < 1 || selection > index)); then
                echo "${langEnterError}"
                exit 1
            fi
            let selection-=1
            dispid=$selection
            ;;
        *)
            echo "${langEnterError}"
            exit 1
            ;;
        esac
    else
        dispid=0
    fi

    VendorID=${vends[$dispid]}
    ProductID=${prods[$dispid]}
    Vid=($(printf '%x\n' ${VendorID}))
    Pid=($(printf '%x\n' ${ProductID}))
}

function init() {
    rm -rf ${currentDir}/tmp/
    mkdir -p ${currentDir}/tmp/

    libDisplaysDir="/Library/Displays"
    targetDir="${libDisplaysDir}/Contents/Resources/Overrides"
    sysDisplayDir="/System${targetDir}"
    Overrides="\/Library\/Displays\/Contents\/Resources\/Overrides"
    sysOverrides="\/System${Overrides}"

    if [[ ! -d "${targetDir}" ]]; then
        sudo mkdir -p "${targetDir}"
    fi

    downloadHost="https://raw.githubusercontent.com/xzhih/one-key-hidpi/master"
    if [ -d "${currentDir}/displayIcons" ]; then
        downloadHost="file://${currentDir}"
    fi

    DICON="com\.apple\.cinema-display"
    imacicon=${sysOverrides}"\/DisplayVendorID\-610\/DisplayProductID\-a032\.tiff"
    mbpicon=${sysOverrides}"\/DisplayVendorID\-610\/DisplayProductID\-a030\-e1e1df\.tiff"
    mbicon=${sysOverrides}"\/DisplayVendorID\-610\/DisplayProductID\-a028\-9d9da0\.tiff"
    lgicon=${sysOverrides}"\/DisplayVendorID\-1e6d\/DisplayProductID\-5b11\.tiff"
    proxdricon=${Overrides}"\/DisplayVendorID\-610\/DisplayProductID\-ae2f\_Landscape\.tiff"
    
    if [[ $is_applesilicon == true ]]; then
        get_vidpid_applesilicon
    else
        get_edid
    fi

    if [[ -z $VendorID || -z $ProductID || $VendorID == 0 || $ProductID == 0 ]]; then
        echo "$langNoMonitFound"
        exit 2
    fi

    echo "$langMonitVIDPID $Vid:$Pid"
    generate_restore_cmd
}

function generate_restore_cmd() {
    if [[ $is_applesilicon == true ]]; then
        cat >"$(cd && pwd)/.hidpi-disable" <<-\CCC
#!/bin/bash
function get_vidpid_applesilicon() {
    local index=0
    local prodnamesindex=0
    local selection=0
    local appleDisplClass='AppleCLCD2'

    local vends=($(ioreg -arw0 -d1 -c $appleDisplClass | xpath -q -n -e "$vendIDQuery"))
    local prods=($(ioreg -arw0 -d1 -c $appleDisplClass | xpath -q -n -e "$prodIDQuery"))
    set -o noglob
    IFS=$'\n' prodnames=($(ioreg -arw0 -d1 -c $appleDisplClass | xpath -q -n -e "$prodNameQuery"))
    set +o noglob

    if [[ "${#prods[@]}" -ge 2 ]]; then
        echo '              Monitors              '
        echo '------------------------------------'
        echo '  Index  |  VendorID  |  ProductID  '
        echo '------------------------------------'
        for prod in "${prods[@]}"; do
            MonitorName=${prodnames[$prodnamesindex]}
            VendorID=$(printf "%04x" ${vends[$index]})
            ProductID=$(printf "%04x" ${prods[$index]})
            let index++
            let prodnamesindex++
            if [[ ${VendorID} == 0610 ]]; then
                MonitorName="Apple Display"
                let prodnamesindex--
            fi
            printf "    %d    |    ${VendorID}    |     ${ProductID}    |  ${MonitorName}\n" ${index}
        done

        echo "------------------------------------"
        read -p "Choose the display:" selection
        case $selection in
        [[:digit:]]*)
            if ((selection < 1 || selection > index)); then
                echo "Enter error, bye"
                exit 1
            fi
            let selection-=1
            dispid=$selection
            ;;
        *)
            echo "Enter error, bye"
            exit 1
            ;;
        esac
    else
        dispid=0
    fi

    VendorID=${vends[$dispid]}
    ProductID=${prods[$dispid]}
    Vid=($(printf '%x\n' ${VendorID}))
    Pid=($(printf '%x\n' ${ProductID}))
}

get_vidpid_applesilicon
CCC
    else
        cat >"$(cd && pwd)/.hidpi-disable" <<-\CCC
#!/bin/sh
function get_edid() {
    local index=0
    local selection=0
    gDisplayInf=($(ioreg -lw0 | grep -i "IODisplayEDID" | sed -e "/[^<]*</s///" -e "s/\>//"))
    if [[ "${#gDisplayInf[@]}" -ge 2 ]]; then
        echo '              Monitors              '
        echo '------------------------------------'
        echo '  Index  |  VendorID  |  ProductID  '
        echo '------------------------------------'
        for display in "${gDisplayInf[@]}"; do
            let index++
            printf "    %d    |    ${display:16:4}    |    ${display:22:2}${display:20:2}\n" $index
        done
        echo '------------------------------------'
        read -p "Choose the display: " selection
        case $selection in
        [[:digit:]]*)
            if ((selection < 1 || selection > index)); then
                echo "Enter error, bye"
                exit 1
            fi
            let selection-=1
            gMonitor=${gDisplayInf[$selection]}
            ;;
        *)
            echo "Enter error, bye"
            exit 1
            ;;
        esac
    else
        gMonitor=${gDisplayInf}
    fi

    EDID=$gMonitor
    VendorID=$((0x${gMonitor:16:4}))
    ProductID=$((0x${gMonitor:22:2}${gMonitor:20:2}))
    Vid=($(printf '%x\n' ${VendorID}))
    Pid=($(printf '%x\n' ${ProductID}))
}

get_edid
CCC
    fi

    cat >>"$(cd && pwd)/.hidpi-disable" <<-\CCC
if [[ -z $VendorID || -z $ProductID || $VendorID == 0 || $ProductID == 0 ]]; then
    echo "No monitors found. Exiting..."
    exit 2
fi

echo "Your monitor VID/PID: $Vid:$Pid"

rootPath="../.."
restorePath="${rootPath}/Library/Displays/Contents/Resources/Overrides"

echo ""
echo "(1) Disable HIDPI on this monitor"
echo "(2) Reset all settings to macOS default"
echo ""

read -p "Enter your choice [1~2]: " input
case ${input} in
1)
    if [[ -f "${restorePath}/Icons.plist" ]]; then
        ${rootPath}/usr/libexec/plistbuddy -c "Delete :vendors:${Vid}:products:${Pid}" "${restorePath}/Icons.plist"
    fi
    if [[ -d "${restorePath}/DisplayVendorID-${Vid}" ]]; then
        rm -rf "${restorePath}/DisplayVendorID-${Vid}"
    fi
    ;;
2)
    rm -rf "${restorePath}"
    ;;
*)
    echo "Enter error, bye"
    exit 1
    ;;
esac

echo "HIDPI Disabled"
CCC

    chmod +x "$(cd && pwd)/.hidpi-disable"
}

function choose_icon() {
    rm -rf ${currentDir}/tmp/
    mkdir -p ${currentDir}/tmp/
    mkdir -p ${currentDir}/tmp/DisplayVendorID-${Vid}
    curl -fsSL "${downloadHost}/Icons.plist" -o ${currentDir}/tmp/Icons.plist

    echo ""
    echo "-------------------------------------"
    echo "|********** ${langChooseIcon} ***********|"
    echo "-------------------------------------"
    echo ""
    echo "(1) iMac"
    echo "(2) MacBook"
    echo "(3) MacBook Pro"
    echo "(4) LG ${langDisplay}"
    echo "(5) Pro Display XDR"
    echo "(6) ${langNotChange}"
    echo ""

    read -p "${langInputChoice} [1~6]: " logo
    case ${logo} in
    1)
        Picon=${imacicon}
        RP=("33" "68" "160" "90")
        curl -fsSL "${downloadHost}/displayIcons/iMac.icns" -o ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.icns
        ;;
    2)
        Picon=${mbicon}
        RP=("52" "66" "122" "76")
        curl -fsSL "${downloadHost}/displayIcons/MacBook.icns" -o ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.icns
        ;;
    3)
        Picon=${mbpicon}
        RP=("40" "62" "147" "92")
        curl -fsSL "${downloadHost}/displayIcons/MacBookPro.icns" -o ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.icns
        ;;
    4)
        Picon=${lgicon}
        RP=("11" "47" "202" "114")
        cp ${sysDisplayDir}/DisplayVendorID-1e6d/DisplayProductID-5b11.icns ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.icns
        ;;
    5)
        Picon=${proxdricon}
        RP=("5" "45" "216" "121")
        curl -fsSL "${downloadHost}/displayIcons/ProDisplayXDR.icns" -o ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.icns
        if [[ ! -f ${targetDir}/DisplayVendorID-610/DisplayProductID-ae2f_Landscape.tiff ]]; then
            curl -fsSL "${downloadHost}/displayIcons/ProDisplayXDR.tiff" -o ${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}.tiff
            Picon=${Overrides}"\/DisplayVendorID\-${Vid}\/DisplayProductID\-${Pid}\.tiff"
        fi
        ;;
    6)
        rm -rf ${currentDir}/tmp/Icons.plist
        ;;
    *)
        echo "${langEnterError}"
        exit 1
        ;;
    esac

    if [[ ${Picon} ]]; then
        DICON=${Overrides}"\/DisplayVendorID\-${Vid}\/DisplayProductID\-${Pid}\.icns"
        /usr/bin/sed -i "" "s/VID/${Vid}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/PID/${Pid}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/RPX/${RP[0]}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/RPY/${RP[1]}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/RPW/${RP[2]}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/RPH/${RP[3]}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/PICON/${Picon}/g" ${currentDir}/tmp/Icons.plist
        /usr/bin/sed -i "" "s/DICON/${DICON}/g" ${currentDir}/tmp/Icons.plist
    fi
}

function inject_edid_only() {
    choose_icon
    sudo mkdir -p ${currentDir}/tmp/DisplayVendorID-${Vid}
    dpiFile=${currentDir}/tmp/DisplayVendorID-${Vid}/DisplayProductID-${Pid}
    sudo chmod -R 777 ${currentDir}/tmp/

    # 仅生成EDID相关配置，移除所有HIDPI分辨率设置
    cat >"${dpiFile}" <<-\CCC
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>DisplayProductID</key>
        <integer>PID</integer>
        <key>DisplayVendorID</key>
        <integer>VID</integer>
        <key>IODisplayEDID</key>
        <data>EDid</data>
    </dict>
</plist>
CCC

    # 处理Apple Silicon的EDID生成（如果需要）
    if [[ $is_applesilicon == false && -n $EDID ]]; then
        version=${EDID:38:2}
        basicparams=${EDID:40:2}
        checksum=${EDID:254:2}
        newchecksum=$(printf '%x' $((0x${checksum} + 0x${version} + 0x${basicparams} - 0x04 - 0x90)) | tail -c 2)
        newedid=${EDID:0:38}0490${EDID:42:6}e6${EDID:50:204}${newchecksum}
        EDid=$(printf ${newedid} | xxd -r -p | base64)
    else
        # Apple Silicon使用检测到的基础EDID
        EDid=$(printf $(printf "%04x%04x" $VendorID $ProductID) | xxd -r -p | base64)
    fi

    /usr/bin/sed -i "" "s/VID/$VendorID/g" ${dpiFile}
    /usr/bin/sed -i "" "s/PID/$ProductID/g" ${dpiFile}
    /usr/bin/sed -i "" "s:EDid:${EDid}:g" ${dpiFile}

    # 保持原有权限和复制逻辑
    sudo chown -R root:wheel ${currentDir}/tmp/
    sudo chmod -R 0755 ${currentDir}/tmp/
    sudo chmod 0644 ${currentDir}/tmp/DisplayVendorID-${Vid}/*
    sudo cp -r ${currentDir}/tmp/* ${targetDir}/
    sudo rm -rf ${currentDir}/tmp
    echo "${langEnabled}"
    echo "${langEnabledLog}"
}

function disable() {
    echo ""
    echo "${langDisableOpt1}"
    echo "${langDisableOpt2}"
    echo ""

    read -p "${langInputChoice} [1~2]: " input
    case ${input} in
    1)
        if [[ -f "${targetDir}/Icons.plist" ]]; then
            sudo /usr/libexec/plistbuddy -c "Delete :vendors:${Vid}:products:${Pid}" "${targetDir}/Icons.plist"
        fi
        if [[ -d "${targetDir}/DisplayVendorID-${Vid}" ]]; then
            sudo rm -rf "${targetDir}/DisplayVendorID-${Vid}"
        fi
        ;;
    2)
        sudo rm -rf "${targetDir}"
        ;;
    *)
        echo "${langEnterError}"
        exit 1
        ;;
    esac

    echo "${langDisabled}"
}

function start() {
    init
    echo ""
    opt=1
    printf "${langInjectEDID}\n" $opt
    let opt++
    printf "${langDisableHIDPI}\n" $opt
    echo ""

    read -p "${langInputChoice} [1~$opt]: " input
    case ${input} in
    1)
        inject_edid_only
        ;;
    2)
        disable
        ;;
    *)
        echo "${langEnterError}"
        exit 1
        ;;
    esac
}

start