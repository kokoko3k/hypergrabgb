#!/bin/bash
export IFS=$'\n'
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
unload_modules(){
	#Elimina tutti i moduli Record-and-Play (potrebbero essere più di uno se lo script non è uscito bene in passato)
	for module in $(pacmd list-modules|grep -B5 -i 'Record-and-Play'|grep index|cut -d ":" -f 2) ; do
		pacmd unload-module $module
	done
	echo "done unload_modules"
}


#Clean function
finish() {
    echo ; echo TRAP: finish.
    kill $ffpid
	unload_modules
	#ripristina il modulo module-stream-restore (occhio che non controllo che prima fosse attivo)
		pactl unload-module module-stream-restore
		pactl load-module module-stream-restore restore_device=true
}
trap finish INT TERM EXIT

#Pulizia iniziale
	unload_modules

#Dici a pulseaudio di non ripristinare i vecchi sink per le applicazioni conosciute:
	pactl unload-module module-stream-restore
	pactl load-module module-stream-restore restore_device=false

#Crea un dispositivo per catturare diverso dal monitor alsa, così che non sia influenzato dalla regolazione del volume:
	pacmd load-module module-combine-sink sink_name=record-n-play slaves=alsa_output.pci-0000_00_1b.0.analog-stereo sink_properties=device.description="Record-and-Play" resample_method=auto
	pacmd set-default-sink record-n-play

#Muovi le stream già in play
	record_sync=$(pactl list short sinks|grep record-n-play |cut -s -f 1)
	for stream in $(pactl list short sink-inputs|grep -vi module-combine|cut -s -f 1) ; do
		pactl move-sink-input $stream $record_sync
	done

	
#ffmpeg -nostdin -y -loglevel quiet -fflags fastseek+flush_packets -flags low_delay -analyzeduration 0  -probesize 32 \
#	-framerate 50 \
#	-i /koko/tmp/vmeter.png \
#	-f pulse -ac 2 -i record-n-play.monitor \
#	-filter_complex \
#	"[1:a]showvolume=o=v:t=false:v=false:b=0:f=0:r=50:w=80:h=71:f=0:p=1:c=0x00000000,crop=h=65:w=115,scale=16:9,setpts=0.5*PTS[meter],[0:v][meter]overlay[out]" \
#	-map [out] \
#	-vcodec rawvideo -f  nut - |ffplay -loglevel quiet -nostats -flags low_delay  -probesize 32 -fflags nobuffer+fastseek+flush_packets -analyzeduration 0 -sync ext -


ffmpeg -nostdin -y -loglevel quiet -fflags fastseek+flush_packets -flags low_delay -analyzeduration 0  -probesize 32 \
	-framerate 50 \
	-i $SCRIPT_DIR/vmeter.png \
	-f pulse -ac 2 -i record-n-play.monitor \
	-filter_complex \
	"[1:a]showvolume=o=v:t=false:v=false:b=0:f=0:r=50:w=80:h=71:f=0:p=1:c=0x00000000,crop=h=65:w=115,scale=16:9,setpts=0.5*PTS[meter],[0:v][meter]overlay[out]" \
	-map [out] \
	 -pix_fmt rgb24 -vcodec rawvideo -f image2pipe - 
	


