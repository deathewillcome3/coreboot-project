#!/usr/bin/bash
machine_type="t520"
top_bios=""
bot_bios=""
full_bios="full_bios.rom"

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
    for r in {0..2}
    do
        for c in {0..2} 
        do
            diff $1$r.bin $1$c.bin >> $1.log
        done
    done
    echo "$1$r.bin"
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
extract_blobs() {
    mkdir bios_dump && cd bios_dump
    ifdtool -x ../$full_bios
    echo "Elevating permissions to add blobs to coreboot directory"
    rename 's/.{14}//' *.bin
    sudo mkdir -p /etc/coreboot/3rdparty/blobs/mainboard/lenovo/$machine_type && sudo cp * /etc/coreboot/3rdparty/blobs/mainboard/lenovo/$machine_type
    cd ..
}
build_core(){
    sudo rm /etc/coreboot/.config
    echo "Press y if you want to build for intel_wifi, press anything else for FOSS"
    read free
    if [ "$free" == "y" ] || [ "$free" == "Y" ]
    then
        sudo cp "model_builds/intel_$machine_type" /etc/coreboot/.config
    else
        sudo cp "model_builds/free_$machine_type" /etc/coreboot/.config
    fi
    sudo chmod 777 /etc/coreboot/.config
    local work_dir=$PWD
    cd /etc/coreboot/
    make crossgcc-i386 CPUS=4
    make iasl
    make
    cd $work_dir
}
full_build(){
     extract_blobs "$1"
     build_core
    if [ "$2" == true ]
    then
        echo "Please position clip on 8M / BOTTOM CHIP"
        flash "/etc/coreboot/build/coreboot.rom"
    else
        echo "Please position clip on 8M / BOTTOM CHIP"
        sleep_counter 360
        dd if=/etc/coreboot/build/coreboot.rom of=8M.rom bs=1M count=8
        dd if=/etc/coreboot/build/coreboot.rom of=4M.rom bs=1M skip=8
        flash 8M.rom
        echo "Finished Flashing 8M / BOTTOM CHIP, please connect clip to 4M / TOP CHIP"
        sleep_counter 360
        flash 4M.rom
    fi
}
flash(){
    flashrom -p ch341a_spi -w $1
    if [ $? -eq 0 ] 
    then
        echo "Yay! Your flash worked!"
    else
        echo "Error in Running Command, retrying in 30 seconds"
        sleep_counter "120"
        flashrom -p ch341a_spi -r $1$i.bin
    fi
}

echo "Reading Flash for the 8M / Bottom Chip"
read_flash "bottom"

echo "Please Reseat chip onto 4M / Top flash chip"
echo "Press the A key to speed it up"
echo " "
sleep_counter "360"

read_flash "top"

bot_bios="$(compare "bottom")"
top_bios="$(compare "top")"
diff $bot_bios $top_bios >> diff.log
echo $PWD
if [ ! -s top.log ] && [ ! -s bottom.log ] 
then
    if [ -s diff.log ]
    then
        cat $top_bios $bot_bios > $full_bios
        full_build "$full_bios" "false"
    else
        echo "Please confirm that you are flashing an xx20 series, otherwise halt the program and retry"
        sleep_counter "20"
        is20=true;
        full_bios=$top_bios
        full_build "$full_bios" "true"
    fi
else
    echo "The files seem to be different please retry reading and check the log files"
fi
