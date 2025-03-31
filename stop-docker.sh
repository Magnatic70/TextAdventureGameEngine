#!/bin/bash
docker stop $(docker ps -q --filter ancestor=adventure-game-engine )
