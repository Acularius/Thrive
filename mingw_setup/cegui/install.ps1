param(
    [string]$MINGW_ENV
)

#########
# CEGUI #
#########

Write-Output "--- Installing CEGUI ---"

$DIR = Split-Path $MyInvocation.MyCommand.Path

#################
# Include utils #
#################

. (Join-Path "$DIR\.." "utils.ps1")


############################
# Create working directory #
############################

$WORKING_DIR = Join-Path $MINGW_ENV temp\cegui

mkdir $WORKING_DIR -force | out-null


###################
# Check for 7-Zip #
###################

$7z = Join-Path $MINGW_ENV "temp\7zip\7za.exe"

if (-Not (Get-Command $7z -errorAction SilentlyContinue))
{
    return $false
}


####################
# Download archive #
####################


$REMOTE_DIR="http://downloads.sourceforge.net/project/crayzedsgui/CEGUI%20Mk-2/0.8"

$LIB_NAME="cegui-0.8.3"

$ARCHIVE=$LIB_NAME + ".zip"

$DESTINATION = Join-Path $WORKING_DIR $ARCHIVE

if (-Not (Test-Path $DESTINATION)) {
    Write-Output "Downloading archive..."
    $CLIENT = New-Object System.Net.WebClient
    $CLIENT.DownloadFile("$REMOTE_DIR/$ARCHIVE", $DESTINATION)
}
else {
    Write-Output "Found archive file, skipping download."
}

##########
# Unpack #
##########

Write-Output "Unpacking archive..."

$ARGUMENTS = "x",
             "-y",
             "-o$WORKING_DIR",
             $DESTINATION
             
& $7z $ARGUMENTS


###########
# Compile #
###########

Write-Output "Compiling..."

$env:Path += (Join-Path $MINGW_ENV bin) + ";"

$TOOLCHAIN_FILE="$MINGW_ENV/cmake/toolchain.cmake"

$BUILD_TYPES = @("Debug", "Release")


foreach ($BUILD_TYPE in $BUILD_TYPES) {

    $BUILD_DIR = Join-Path $WORKING_DIR "build-$BUILD_TYPE"
    
    #Fetch the dependencies
    $DEPS_LOC = "$MINGW_ENV/temp/cegui_deps/build-" + $BUILD_TYPE + "/dependencies"
    $DEPS_TARGET = "$WORKING_DIR/" + $LIB_NAME
    Copy-Item $DEPS_LOC -destination $DEPS_TARGET -Recurse -Force
    

    $BUILD_DIR = Join-Path $WORKING_DIR "build-$BUILD_TYPE"

    mkdir $BUILD_DIR -force

    pushd $BUILD_DIR

    $LIB_SRC = Join-Path $WORKING_DIR $LIB_NAME
    
    # hacky way to add tinyxml dependency, the cegui_deps didn't seem to build it correctly so we do it manually
    $ARGUMENTS =
        "-DCMAKE_INSTALL_PREFIX=$MINGW_ENV/install",
        "-DCMAKE_BUILD_TYPE=$BUILD_TYPE",
        "-DCEGUI_BUILD_XMLPARSER_TINYXML:bool=TRUE",
        "-DCEGUI_OPTION_DEFAULT_XMLPARSER:string=TinyXMLParser",
        "-DTINYXML_H_PATH:path=$MINGW_ENV/install/include/tinyxml",
        "-DTINYXML_LIB_DBG:filepath=$MINGW_ENV/install/lib/libtinyxml.a",
        "$LIB_SRC"

    & (Join-Path $MINGW_ENV cmake\bin\cmake) -G "MinGW Makefiles" $ARGUMENTS

    & $MINGW_ENV/bin/mingw32-make -j4 install


    
    popd

}
#Move the include directory one level out so includes don't have to do #include cegui-0/CEGUI/myceguiheader.h
if (Test-Path $MINGW_ENV\install\include\CEGUI){
    Remove-Item -Force $MINGW_ENV\install\include\CEGUI -Recurse
}
Move-Item -path  $MINGW_ENV\install\include\cegui-0\CEGUI -destination $MINGW_ENV\install\include -Force
Remove-Item -Force $MINGW_ENV\install\include\cegui-0 -Recurse

