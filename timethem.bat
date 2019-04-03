Echo "all start" > w:\basla.txt
Echo "ffmpeg hwaccel start" >> w:\basla.txt
time /t >> w:\basla.txt
"C:\Users\noyana\Documents\Visual Studio 2017\Projects\Videos\ffmpeg.exe" -i "P:\Diziler\Raw\Florane Russell (12).mp4" -codec:v h264_amf -s 854x480  -b:v 768k -r 25 -codec:a aac -b:a 128k -ar 44100  -y -preset ultrafast -tune film -map 0:0 -map 0:1 -strict experimental -af aresample=resampler=soxr "W:\Florane Russell (A).mp4"
Echo "ffmpeg hwaccel end" >> w:\basla.txt
time /t >> w:\basla.txt

Echo "ffmpeg no hwaccel start" >> w:\basla.txt
time /t >> w:\basla.txt
"C:\Users\noyana\Documents\Visual Studio 2017\Projects\Videos\ffmpeg.exe" -i "P:\Diziler\Raw\Florane Russell (12).mp4" -codec:v libx264 -s 854x480  -b:v 768k -r 25 -codec:a aac -b:a 128k -ar 44100  -threads 3 -y -preset ultrafast -tune film -map 0:0 -map 0:1 -strict experimental -af aresample=resampler=soxr "W:\Florane Russell (4).mp4"
Echo "ffmpeg no hwaccel end" >> w:\basla.txt
time /t >> w:\basla.txt

Echo "HB start" >> w:\basla.txt
time  /t >> w:\basla.txt
"C:\Users\noyana\Documents\Visual Studio 2017\Projects\Videos\HandBrakeCLI.exe" --input "P:\Diziler\Raw\Florane Russell (12).mp4" --preset-import-file "C:\Users\noyana\Documents\Visual Studio 2017\Projects\Videos\Galaxy.json" --preset Galaxy --subtitle none --output "W:\Florane Russell (H).mp4"
Echo "HB end" >> w:\basla.txt
time /t >> w:\basla.txt
