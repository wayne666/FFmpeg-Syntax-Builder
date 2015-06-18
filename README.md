# FFmpeg::Syntax::Builder 

build complex ffmpeg command easier


-------------------

## DESCRIPTION

A simple ffmpeg command line untility, make ffmpeg command easier

## SYNOPSIS

	use FFmpeg::Syntax::Builder;
	
	my $ffmpeg_builder = FFmpeg::Syntax::Builder->new();

### add_input function

#### Support mutiple inputs like udp, rtmp, file(localfile), stdin(bmdcapture)

	$ffmpeg_builder->add_input(stdin); # you can assign your sid_port and sid_mode
	
	$ffmpeg_builder->add_input(udp   => {url  => "udp://ip"});
	
	$ffmpeg_builder->add_input(ip    => {rtmp => "rtmp://ip"});
	
	$ffmpeg_builder->add_input(file  => {filepath => $local_file_path});

#### Add watermark file
  
	$ffmpeg_builder->add_input(watermark  => {filepath => '/tmp/xxx.jpeg'});

### Support multiple outputs, you should use add_vf_split

#### use channel_id to distinguish different channel live

	$ffmpeg_builder->add_vf_split(udp => {channel_id => $channel_id}); # [0:p:$channel_id:0]
	
	$ffmpeg_builder->add_vf_split(ip  => {channel_id => $channel_id}); # [$channel_id:0]

#### Add watermark position argv, default is top_left, you can assgin top_right/bottom_left/bottom_right

	$ffmpeg_builder->add_vf_split(watermark => {water_positon => 'top_left'})

#### Add YUV format

	$ffmpeg_builder->add_vf_split('format');

#### Add deinterlace, $deinterlace default is "yadif=0:-1"

	$ffmpeg_builder->add_vf_split(deinterlace => $deinterlace);

#### Add split output 

	$ffmpeg_builder->add_vf_split(output_count => $output_count);

### add_vf function add video filter

#### Add fps (frame per seconds), default is 25

	$ffmpeg_builder->add_vf('fps' => $fps);

#### Add scale 

	$ffmpeg_builder->add_vf('scale' => {width => $width, height => $height});

#### Add vf 

	$ffmpeg_builder->add_vf(vf => $vf_string);

#### Add drawtext, you must assgin ttf font file, logo_text, fontsize 

	$ffmpeg_builder->add_vf( 'drawtext' => {
								fontfile  => '/data1/sue/rc/san_serif.ttf',
				  				logo_text => $logo_text,
				  				fontsize  => $o_fontsize });

#### Add set dar

	$ffmpeg_builder->add_vf(dar => {width => $width, height => $height} );
  
#### Add output tag

	$ffmpeg_builder->add_vf('output_tag');

#### Add Audio

#### Add udp or ip, assgin channel_id

	$ffmpeg_builder->add_vf_split(udp => {channel_id => $channel_id}); # [0:p:$channel_id:0]

	$ffmpeg_builder->add_vf_split(ip  => {channel_id => $channel_id}); # [$channel_id:0]

### add_af function add audio codec

#### Add mono

	$ffmpeg_builder->add_af('mono');

#### Add volume, turn volume up or down, default is AUTO

	$ffmpeg_builder->add_af('volume');

#### Add async to async video and audio

	$ffmpeg_builder->add_af('async');

#### Add audio delay 

	$ffmpeg_builder->add_af(audio_delay => {audio_delay_msecs => 15});

#### Add output count

$ffmpeg_builder->add_af(output_count => 1); 

### add_output function add output type

#### Add output $ffmepg_builder->add_output('map_av'); #### Add codec video x264opts

	$ffmpeg_builder->add_output(codec_video => {x264opts => $x264opts});

#### Add vsync 

	$ffmpeg_builder->add_output('vsync' => { vsync_mode => 2 });

#### Add codec audio 

	$ffmpeg_builder->add_output('codec_audio' => { abitrate => "libfdk_aac -b:a 16k" });

#### Add output type, support rtmp/rtsp/file(localfile)

	$ffmpeg_builder->add_output('rtmp' => { url => $rtmp_url });

	$ffmpeg_builder->add_output('rtmp' => { url => $rtsp_url });

#### Assgin the log file. If you do not assgin the logfile, default is log to stderr

	$ffmpeg_builder->log_output(logpath => '/tmp', logname => 'test')

#### Run the command

	$ffmpeg_builder->run();

## METHODS

#### add_input()

	Assgin the input type which you want

#### add_vf_split()

	When you have multiple outputs, you must split multiple outpus

#### add_vf()

	Assgin the codec videu

#### add_af()

	Assgin the codec audio

#### add_output()

	Assgin the output type which you want
#### log_output()

	Print ffmpeg command output to logfile 

#### run()

	Run the command

## AUTHOR

Thanks for ChenGang. Written by WayneZhou, cumtxhzyyatgmail.com

## COPYRIGHT

Copyright (c) 2015 WayneZhou. This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

