#!/bin/bash
docker run -d --name AGE --restart unless-stopped -p 4546:4546 -v /media/BigVolume/Ontwikkel/AdventureGameEngine/adventures:/app/adventures -v /media/BigVolume/Ontwikkel/AdventureGameEngine/sessions:/app/sessions adventure-game-engine

