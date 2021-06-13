ffmpeg -loop 1  -i "/tmp/video/IMG_%06d.jpg" \
	-vcodec libx264 -crf 25  -pix_fmt yuv420p -t 15  \
	-vf "setpts=4*PTS" /tmp/video.mp4
