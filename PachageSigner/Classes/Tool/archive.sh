#!/bin/bash

#################################################
##############    配置（config）    ##############
#################################################

# 生成ipa文件的名称
IPA_NAME="xxx"

# 生成ipa的目录
APP_DIR="/Users/xxx/Desktop/xxx"

# 项目的目录
PROJECT_DIR="/Users/xxx/xxx"

# 输出IPA配置目录
EXPORT_DIR="/Users/xxx/xxx/exportOptions.plist"

# 编译build路径
ARCHIVE_NAME="Products"

# workplace的名字
PROJECT_NAME="xxx"

# scheme的名字
SCHEME_NAME="xxx"

# 分发或者发布
CONFIGURATION="Release"

# 上传类型（Re-Bale Only(仅打包)、AppStore、蒲公英、FIR）
UPLOAD_ADDRESS="Re-Bale Only"

# AppStore 参数
# 开发者账号
APPSTORE_ACCOUNT=""
# 开发者密码
APPSTORE_PASSWORD=""

# 蒲公英 平台参数
# 开发者的用户 Key，在应用管理-API中查看
PGYER_USER_KEY=""
# 开发者的 API Key，在应用管理-API中查看
PGYER_API_KEY=""

# FIR平台的token
FIR_TOKEN=""

#################################################
############    执行代码（execute）    ############
#################################################

function failed() {
    echo "执行耗时: $@" >&2
    exit 1
}

# timestamp=`date "+%Y%m%d%H%M%S"`
script_dir_relative=`dirname $0`
script_dir=`cd ${script_dir_relative}; pwd`
echo "script_dir = ${script_dir}"

echo -e '开始打包...\n'
echo -e '读取配置...\n'

# 创建ipa包存放目录 重新命名文件夹
rm -rf ${APP_DIR}
mkdir -pv ${APP_DIR} || failed "mkdir ${APP_DIR}"

# 切换到工程目录
cd ${PROJECT_DIR} || failed "cd ${PROJECT_DIR}"

# 清空 ARCHIVE_NAME 并重新创建，指定编译build路径
rm -rf ${ARCHIVE_NAME} 
mkdir -pv ${ARCHIVE_NAME} || failed "mkdir ${ARCHIVE_NAME}"
ARCHIVE_PATH=${ARCHIVE_NAME}/${PROJECT_NAME}.xcarchive

# workspace/xcodeproj 路径(根据项目是否使用cocoapod,确定打包的方式)
if [ -d ${PROJECT_DIR}/${PROJECT_NAME}.xcworkspace ];then # 项目中存在workspace
    isWorkSpace=YES
    WORKSPACE_PATH=${PROJECT_DIR}/${PROJECT_NAME}.xcworkspace
else # 项目中不存在 workspace
    isWorkSpace=NO
    WORKSPACE_PATH=${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj
fi

echo -e '正在清理工程...\n'
# 根据工程 workspace/xcodeproj ,确定清理工程的方式)
if [ ${isWorkSpace} == YES ]; then
    xcodebuild -workspace ${WORKSPACE_PATH} -scheme ${SCHEME_NAME} clean -quiet || failed "xcodebuild xcworkspace clean failure"
 else
    xcodebuild -project ${WORKSPACE_PATH} clean -quiet || failed "xcodebuild xcodeproj clean failure"
fi

echo -e '清理完成-->>>--正在编译工程:'${CONFIGURATION}'\n'

# 根据工程 workspace/xcodeproj 确定打包的方式
if [ ${isWorkSpace} == YES ];then # 项目中存在workspace
    xcodebuild archive -workspace ${WORKSPACE_PATH} -scheme ${SCHEME_NAME} \
    -configuration ${CONFIGURATION} \
    -archivePath ${ARCHIVE_PATH} -quiet || failed "xcodebuild xcworkspace archive failure"
else #通过xcodeproj 方式打包
    xcodebuild archive -project ${WORKSPACE_PATH} -scheme ${SCHEME_NAME} \
    -configuration ${CONFIGURATION} \
    -archivePath ${ARCHIVE_PATH} -quiet || failed "xcodebuild xcodeproj archive failure"
fi

# 检查是否构建成功(build)
if [ $? ] ; then
    echo -e '项目构建成功\n'
else
    echo '项目构建失败'
    failed
fi

echo -e '编译完成-->>>--开始ipa打包\n'

# 工程目录下 ${PROJECT_NAME} xcarchive 到处ipa包
xcodebuild -exportArchive -archivePath ${ARCHIVE_PATH} \
-configuration ${CONFIGURATION} \
-exportPath ${ARCHIVE_NAME} \
-exportOptionsPlist ${EXPORT_DIR} \
-quiet || failed "xcodebuild export archive failure"

if [ $? ]; then
    echo -e 'ipa打包成功\n'
else
    echo 'ipa打包失败'
    failed
fi

#################################################
#############    清理代码（clear）    #############
#################################################

echo -e '打包完成-->>>--移动ipa包到指定目录\n'
mv ${ARCHIVE_NAME}/${PROJECT_NAME}.ipa ${APP_DIR}/${IPA_NAME}.ipa || failed "mv ipa failure"

echo -e '清理build...\n'
rm -rf ${ARCHIVE_NAME}

echo -e '清理完成\n'

#################################################
#########    上传服务（UploadService）    #########
#################################################

if [[ ${UPLOAD_ADDRESS} != "Re-Bale Only" ]]; then
    echo -e '开始发布服务...\n'
    echo -e '读取配置...\n'
    if [[ ${UPLOAD_ADDRESS} == 'App Store' ]]; then
        echo -e '发布IPA至-->>>--'${UPLOAD_ADDRESS}
        altoolPath="/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Versions/A/Support/altool"
        "$altoolPath" --validate-app -f ${APP_DIR}/${IPA_NAME}.ipa -u ${APPSTORE_ACCOUNT} -p ${APPSTORE_PASSWORD} -t ios --output-format xml
        "$altoolPath" --upload-app -f ${APP_DIR}/${IPA_NAME}.ipa -u ${APPSTORE_ACCOUNT} -p ${APPSTORE_PASSWORD} -t ios --output-format xml

        if [ $? ]; then
            echo -e '已成功提交至 AppStore'
        else
            echo -e '提交 AppStore 失败！具体错误请查阅输出日志\n'
        fi
    elif [[ ${UPLOAD_ADDRESS} == '蒲公英' ]]; then
        echo '发布IPA至-->>>--蒲公英平台'
        curl -F "file=@${APP_DIR}/${IPA_NAME}.ipa" -F "uKey=${user_key}" -F "_api_key=${api_key}" https://www.pgyer.com/apiv1/app/upload

        if [ $? = 0 ];then
            echo -e 'ipa提交蒲公英成功\n'
        else
            echo -e 'ipa提交蒲公英失败\n'
            failed
        fi
    elif [[ ${UPLOAD_ADDRESS} == 'FIR' ]]; then
        echo '发布IPA至-->>>--fir.im平台'
        # 需要先在本地安装 fir 插件,安装fir插件命令: gem install fir-cli
        fir login -T ${FIR_TOKEN}              # fir.im token
        fir publish ${APP_DIR}/${IPA_NAME}.ipa

        if [ $? = 0 ];then
            echo -e 'ipa提交fir.im成功\n'
        else
            echo -e 'ipa提交提交fir.im失败\n'
            failed
        fi
    fi
else
    echo -e '执行完成\n'
fi

# open ${APP_DIR}
