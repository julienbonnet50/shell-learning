#!/bin/bash

DATA=$(curl --request GET \
	--url 'https://api-football-v1.p.rapidapi.com/v2/odds/league/865927/bookmaker/5?page=2' \
	--header 'x-rapidapi-host: api-football-v1.p.rapidapi.com' \
	--header 'x-rapidapi-key: 201b3cf232msheac4009da4e8824p1cf310jsnc586e49f9217')

echo $DATA