#!/bin/bash

echo "Press [CTRL+C] to stop.."

psql -q -c "create table if not exists instrument_readings (
    id serial,
    instrument_id varchar,
    reading double precision,
    ts timestamp
);"


while :
do
    timestamp=$(date +"%Y-%m-%d %H:%M:%S.%N")

    reading=$(date +%N)
    reading="${reading: -4:1}"."${reading: -3:3}"

    instruments=('kl-928' 'af-3097' 'dxp-08xz')
    len=${#instruments[@]}
    rand=$((RANDOM%$len))
    instrument=${instruments[$rand]}
    psql -q -c "insert into instrument_readings (instrument_id, reading, ts)  VALUES ('$instrument', $reading, '$timestamp'); "
    echo -n .
	sleep 1
done
