#!/bin/bash

DATA_PATH="data/generated.json"
DATA=$(cat $DATA_PATH)

echo $DATA | jq -r '.[] | "\(.name) \(.age)"'