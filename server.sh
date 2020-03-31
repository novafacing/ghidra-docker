#!/bin/bash
GHIDRA_CLASSPATH="$(sed 's/.*\(${ghidra_home}\)/\1/g' "${ghidra_home}/Ghidra/Features/GhidraServer/data/classpath.frag" | sed ':a;N;$!ba;s/\n/:/g'| envsubst )"
: ${GHIDRA_REPOSITORIES_PATH:=/srv/repositories}
#create the users on startup, if users file doesn't exist
if [ ! -e "${GHIDRA_REPOSITORIES_PATH}/users" ] && [ ! -z "${GHIDRA_DEFAULT_USERS}" ]; then
  mkdir -p "${GHIDRA_REPOSITORIES_PATH}/~admin"
  for GHIDRA_DEFAULT_USER in ${GHIDRA_DEFAULT_USERS//,/ }; do
    echo "Creating user ${GHIDRA_DEFAULT_USER} with default password 'changeme'"
    echo "-add ${GHIDRA_DEFAULT_USER}" >> "${GHIDRA_REPOSITORIES_PATH}/~admin/adm.cmd"
  done
fi
exec java \
  -classpath "${GHIDRA_CLASSPATH}" \
  -Djava.net.preferIPv4Stack=true \
  -DApplicationRollingFileAppender.maxBackupIndex=10 \
  -Dclasspath_frag="${ghidra_home}/Ghidra/Features/GhidraServer/data/classpath.frag" \
  -Ddb.buffers.DataBuffer.compressedOutput=true \
  -Djava.library.path="${ghidra_home}/Ghidra/Features/GhidraServer/os/linux64" \
  -XX:InitialRAMPercentage=10 \
  -XX:MinRAMPercentage=10 \
  -XX:MaxRAMPercentage=80 \
  -Djava=/usr/bin/java \
  -Dos_dir="${ghidra_home}/Ghidra/Features/GhidraServer/os/linux64" \
  -Dghidra_home="${ghidra_home}" \
  -Djna_tmpdir=/tmp \
  ghidra.server.remote.GhidraServer \
  -a0 \
  ${GHIDRA_FLAGS:+"$GHIDRA_FLAGS"} \
  "${GHIDRA_REPOSITORIES_PATH}" &
pip3 install jfx_bridge
git clone https://github.com/novafacing/ghidra_bridge.git /tmp/ghidra_bridge
cd /tmp/ghidra_bridge
python3 -m ghidra_bridge.install_server /tmp/ghidra_bridge/test_server
if [[ -d /tmp/TestProject.rep ]]; then
	/opt/ghidra/support/analyzeHeadless /tmp TestProject -noanalysis -scriptPath /tmp/ghidra_bridge/test_server -preScript ghidra_bridge_server.py >/tmp/script.log 2>/tmp/script.err & # Run the ghidra_bridge_server in a headless ghidra - we use non-background server, otherwise the script would exit before we could test
else
	/opt/ghidra/support/analyzeHeadless /tmp TestProject -import /bin/bash -noanalysis -scriptPath /tmp/ghidra_bridge/test_server -preScript ghidra_bridge_server.py >/tmp/script.log 2>/tmp/script.err & # Run the ghidra_bridge_server in a headless ghidra - we use non-background server, otherwise the script would exit before we could test
fi
( tail -f /tmp/script.err & ) | grep -q "_bridge.bridge:serving!" # pause until we see the ghidra_bridge_server start logging messages
python3 -c "import ghidra_bridge; b = ghidra_bridge.GhidraBridge(namespace=globals()); print(getState().getCurrentAddress())"
tail -f /tmp/script.err
