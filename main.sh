#!/usr/bin/bash
sleep_counter() {
    local wait=0
    echo $1
    while [ $wait != $1 ]
    do
        read -r -t 1 -n 1 -s delay
        if [ "$delay" == "a" ] 
        then
            wait=$(($1))
        else
            wait=$(($wait + 1))
            echo -e "\r\033[1A\033[0K$wait/$1 seconds remaining"
        fi
    done
}
compare() {
    touch $i.log
    for r in {0..2}
    do
        for c in {0..2} 
        do
            diff $1$r.bin $1$c.bin >> $1.log
        done
    done
}
read_flash() {
    for i in {0..2}
    do
        flashrom -p ch341a_spi -r $1$i.bin
        if [ $? -eq 0 ] 
        then
            continue
        else
            echo "Error in Running Command, retrying in 30 seconds"
            sleep_counter "120"
            flashrom -p ch341a_spi -r $1$i.bin
        fi
    done
}

# read_flash "bottom"

# echo "Please Reseat chip onto top flash chip"
# echo "Press the A key to speed it up"
# echo " "
# sleep_counter "360"

# read_flash "top"

compare "bottom"
compare "top"

