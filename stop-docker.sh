#!/bin/bash
docker stop $(docker ps -q -l --filter ancestor=adventure-game-engine )
