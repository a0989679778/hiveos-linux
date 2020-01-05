#!/usr/bin/env bash

[[ `ps aux | grep "./beam-cuda-miner" | grep -v grep | wc -l` != 0 ]] &&
	echo -e "${RED}$MINER_NAME miner is already running${NOCOLOR}" &&
	exit 1

cd $MINER_DIR/$MINER_VER

./beam-cuda-miner `cat $MINER_NAME.conf` | tee --append $MINER_LOG_BASENAME.log
