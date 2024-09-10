#!/bin/bash

# prune node
sudo systemctl stop tucana
sleep 5
# prerequisite: install cosmos-pruner https://github.com/notional-labs/cosmprund
$HOME/go/bin/cosmos-pruner prune ~/.tucd/data
sleep 5

# Make sure the service is running
sudo systemctl  start tucana
sleep 10

# Get the block height
BLOCK_HEIGHT=$(curl -s http://localhost:26657/status | jq -r .result.sync_info.latest_block_height)

# Stop service
sudo systemctl stop tucana

# Zip folder
FILENAME=$(echo tucana_${BLOCK_HEIGHT}.tar.lz4)
cd $HOME

tar -cvf - ~/.tucd/data | lz4 > "$HOME/$FILENAME"


# Restart service
sudo systemctl start tucana
