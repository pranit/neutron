#!/bin/bash

# Function to extract and convert individual bits
function extract_value() {
  value=$1
  field=$2

  # Extract relevant bits based on position and mask
  case $field in
    "year")  bits=$((value & 0x7F));;  # Correct mask for year (b0-b6)
    "day")   bits=$((value & 0x1F));;
    "month") bits=$((value >> 8 & 0x0F));;
    "hour")  bits=$((value >> 8 & 0x1F));;
    "min")   bits=$((value & 0x3F));;
    "msec")  bits=$value;;
    "dst")   bits=$((value >> 15 & 0x01));;
    *)      echo "Error: Invalid field name" >&2; exit 1;;
  esac
  # Convert extracted bits to decimal
  echo $((bits))
}

# Execute modpoll command and capture output
modpoll_output=$(/opt/modpoll/x86_64-linux-gnu/modpoll -b 9600 -p none -m rtu -a 4 -r 1830 -c 4 -t 4:hex -1 /dev/ttyS1 | tail -4)

# Extract hex values for relevant registers
year_hex=$(echo "$modpoll_output" | grep "1830" | cut -d':' -f2)
day_month_hex=$(echo "$modpoll_output" | grep "1831" | cut -d':' -f2)
hour_min_hex=$(echo "$modpoll_output" | grep "1832" | cut -d':' -f2)
msec_hex=$(echo "$modpoll_output" | grep "1833" | cut -d':' -f2)

# Extract individual fields using bit manipulation
year=$(extract_value "$year_hex" "year")
# Since year is encoded in bits 0-6, we add 1900 to get the actual year value
year=$((year + 2000))  # Adjust for year encoding (0-127)
day=$(extract_value "$day_month_hex" "day")
month=$(extract_value "$day_month_hex" "month")
hour=$(extract_value "$hour_min_hex" "hour")
minute=$(extract_value "$hour_min_hex" "min")
millisec=$(extract_value "$msec_hex" "msec")
dst_flag=$(extract_value "$hour_min_hex" "dst")

# Construct human-readable datetime

# Apply DST adjustment if needed (implement logic based on your requirements)
# if [[ $dst_flag -eq 1 ]]; then
#   # Adjust datetime for DST
# fi
meter_time=$(date -d "$year-$month-$day $hour:$minute:00 +05:30" +%s%3N)
echo $meter_time
########
epoch_time1=$(date +%s)
epochtime=$epoch_time1*1000
INFLUXDB_URL=""  # Replace with your InfluxDB URL
INFLUXDB_ORG=""
INFLUXDB_BUCKET=""  # Changed to your desired bucket ("neutron")
INFLUXDB_TOKEN=""

# Data to write (replace with your actual data)
# ... (rest of your script to extract timestamp, measurement, value, and tags)

# Prepare data payload in line protocol format
data="meter_time,field=meter_time _value=$meter_time $epoch_time"



# Send data to InfluxDB using curl with authentication
curl -sX POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET" -H "Authorization: Bearer $INFLUXDB_TOKEN" -d "$data"

echo "Data written to InfluxDB (success: $?)"  # $? captures exit code of curl command (0 for success)
