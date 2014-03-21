param(
    [string]$MINGW_ENV
)

######################
# CEGUI Dependencies #
######################

Write-Output "--- Installing CEGUI Dependencies ---"

$DIR = Split-Path $MyInvocation.MyCommand.Path

#################
# Include utils #
#################

. (Join-Path "$DIR\.." "utils.ps1")


############################
# Create working directory #
############################

$WORKING_DIR = Join-Path $MINGW_ENV temp\cegui_deps

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


$REMOTE_DIR="http://prdownloads.sourceforge.net/crayzedsgui"

$ARCHIVE="cegui-deps-0.8.x-src.zip"

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

    mkdir $BUILD_DIR -force

    pushd $BUILD_DIR

    $ARGUMENTS =
        "-DCMAKE_INSTALL_PREFIX=$MINGW_ENV/install",
        "-DCMAKE_BUILD_TYPE=$BUILD_TYPE",
        "-CEGUI_BUILD_LUA=OFF",
        "$WORKING_DIR/cegui-deps-0.8.x-src"

    & (Join-Path $MINGW_ENV cmake\bin\cmake) -G "MinGW Makefiles" $ARGUMENTS

    & $MINGW_ENV/bin/mingw32-make -j4 all


    
    popd
	Copy-Item (Join-Path $BUILD_DIR "\dependencies\*") -destination (Join-Path $MINGW_ENV install) -Recurse -Force

	
	
}


