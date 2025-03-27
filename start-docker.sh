#!/bin/bash
docker run -d --restart unless-stopped -p 4546:4545 -v /media/BigVolume/Ontwikkel/AdventureGameEngine/adventures:/app/adventures -v /media/BigVolume/Ontwikkel/AdventureGameEngine/sessions:/app/sessions adventure-game-engine
