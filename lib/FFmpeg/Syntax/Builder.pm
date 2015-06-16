package FFmpeg::Syntax::Builder;

use 5.008008;
use strict;
use warnings;
use Data::Dumper;
use Log::Lite qw(logpath log);
use POSIX;
use IPC::Open3;

our $VERSION = '0.01';

my %watermark_position = (
    top_left     => '10:10',
    top_right    => 'main_w-overlay_w-10:10',
    bottom_left  => '10:main_h-overlay_h-10',
    bottom_right => 'main_w-overlay_w-10:main_h-overlay_h-10'
);

sub new {
    my $class = shift;
    my $self  = {};

    # 自动找出ffmpeg执行文件的绝对路径备用
    my @PATH = split /:/, $ENV{PATH};
    push @PATH, "./";
    push @PATH, "/bin";
    push @PATH, "/sbin";
    push @PATH, "/usr/bin";
    push @PATH, "/usr/sbin";
    push @PATH, "/usr/local/bin";
    push @PATH, "/usr/local/sbin";
    push @PATH, "/opt";
    push @PATH, "/opt/bin";
    push @PATH, "/opt/sbin";
    my $ffmpeg_exec;

    foreach (@PATH) {
        my $executable = $_ . '/ffmpeg';
        if ( -s $executable ) {
            $self->{ffmpeg_exec} = $executable;
            last;
        }
    }

    # 初始化几个array备用
    $self->{input_options}    = [];
    $self->{vf_options}       = [];
    $self->{output_options}   = [];
    $self->{vf_split_options} = [];
    $self->{af_options}       = [];
    $self->{cmd}              = '';
	$self->{log_path}         = '';
	$self->{logname}	      = '';
    $self->{i_audio}          = 0;
    $self->{i_video}          = 0;
    $self->{input_from_stdin} = 0;    #是否有从stdin进来的输入
    $self->{output_index}     = 0;
	$self->{logfh}	          = *STDERR;


    bless $self, $class;
}

# 可能有多个输入，所以使用add_input而不是set_input
sub add_input {
    my $self = shift;
    my ( $key, $argv ) = @_;
    my $cmd = '';

    if ( $key eq 'stdin' ) {

        # bmdcapture
        $argv->{sdi_port}    = 1  if !defined $argv->{sdi_port};
        $argv->{sdi_mode}    = 2  if !defined $argv->{sdi_mode};
        $argv->{record_pipe} = "" if !defined $argv->{record_pipe};
        $cmd .=
"bmdcapture -c 2 -s 16 -C $argv->{sdi_port} -m $argv->{sdi_mode} -V 4 -A 2 -F nut -f pipe:1 $argv->{record_pipe} | ";
        $cmd .= "$self->{ffmpeg_exec} -re -i - ";
    }

    if ( $key eq 'rtmp' ) {
        $cmd .= "$self->{ffmpeg_exec} -i \"$argv->{url} live=1\" ";
    }

    if ( $key eq 'ip' ) {
        $cmd .= "$self->{ffmpeg_exec} -i $argv->{url} ";
    }

    if ( $key eq 'file' ) {
        $cmd .= "$self->{ffmpeg_exec} -re -i $argv->{filepath} ";
    }

    if ( $key eq 'watermark' ) {
        $cmd .= " -i $argv->{filepath}";
    }

    push @{ $self->{input_options} }, $cmd;
}

sub add_vf_split {
    my $self = shift;
    my ( $key, $argv ) = @_;

    my $cmd = '';
    if ( $key eq 'udp' ) {
        $cmd .= "[0:p:$argv->{channel_id}:0]";
    }

    if ( $key eq 'ip' ) {
        $cmd .= "[$argv->{channel_id}:0]";
    }

    if ( $key eq 'watermark' ) {
        $argv->{i_watermark_position} ||= 'top_left';
        my $watermark_pos =
          $watermark_position{ $argv->{i_watermark_position} };
        $cmd .= "overlay=$watermark_pos,";
    }

    if ( $key eq 'format' ) {
        $cmd .= "format=pix_fmts=yuv420p,";
    }

    if ( $key eq 'deinterlace' ) {
        $argv ||= "yadif=0:-1"; # argv is a string which default is "yadif=0:-1"
        $cmd .= "$argv,";
    }

    if ( $key eq 'split' ) {
        $cmd .= "split=" . $argv->{output_count};
        for ( 0 .. ( $argv->{output_count} - 1 ) ) {
            $cmd .= "[vtmp1$_]";
        }
        $cmd .= ',';
    }

    push @{ $self->{vf_split_options} }, $cmd;
}

sub add_vf {
    my $self = shift;
    my ( $key, $argv ) = @_;
    my $vf_cmd = '';

    my $index = $self->{index_output};

    if ( $key eq 'fps' ) {
        $vf_cmd .= "[vtmp1$self->{output_index}]fps=$argv";
    }

    if ( $key eq 'scale' ) {
        $vf_cmd .= ",scale=$argv->{width}:$argv->{height}";
    }

    if ( $key eq 'vf' ) {
        $vf_cmd .= ",$argv";
        $vf_cmd .= "[vtmp2$self->{output_index}],";
    }

    if ( $key eq 'drawtext' ) {
        $vf_cmd .=
"[vtmp2$self->{output_index}] drawtext=fontfile=$argv->{fontfile}:text='$argv->{logo_text}':x=(w-text_w)*lte(mod(t\\,12)\\,6):y=h-text_h-1:fontsize=$argv->{fontsize}:fontcolor=white\@0.8:shadowx=1:shadowy=1:enable=lte(mod(t\\,6)\\,5)";
    }

    if ( $key eq 'dar' ) {
        $vf_cmd .= ",setdar=dar=$argv->{width}/$argv->{height}";
    }

    if ( $key eq '3d' ) {
        my ( $o_width, $o_height ) = ( $argv->{width}, $argv->{height} );
        my $offset      = 8;
        my $o_3d_width  = int( $o_width / 2 ) + $offset;
        my $o_3d_height = $o_height;
        $vf_cmd .= "[vtmp3$self->{output_index}],";
        $vf_cmd .=
"[vtmp3$self->{output_index}]scale=$o_3d_width:$o_height [vtmp4$self->{output_index}],";
        $vf_cmd .=
"[vtmp4$index]split[main][tmp],[main]crop=$o_3d_width:$o_3d_height:0:0 [left],[tmp]crop=$o_3d_width:$o_3d_height:$offset:0[right],";
        $vf_cmd .= "[right][left]framepack=1[vtmpout],";
        $vf_cmd .= "[vtmpout]scale=$o_width:$o_height";
    }

    if ( $key eq 'output_tag' ) {
        $vf_cmd .= " [vout$self->{output_index}],";
    }

    push @{ $self->{'vf_options'} }, $vf_cmd;
}

sub add_af {
    my $self = shift;
    my ( $key, $argv ) = @_;

    my $cmd = '';

    if ( $key eq 'udp' ) {
        $cmd .= "[0:p:$argv->{i_map}:1]";
    }

    if ( $key eq 'ip' ) {
        $cmd .= "[$argv->{i_map}:a:0]";
    }

    if ( $key eq 'mono' ) {
        $cmd .= "pan=1:c0<c0+c1,";
    }

    if ( $key eq 'volume' ) {
        if ( $argv->{pre_volume} ) {
            $cmd .= "volume=$argv->{pre_volume},";
        }
        else {
            $cmd .= "ebur128=metadata=1,";
        }
    }

    if ( $key eq 'async' ) {
        $cmd .= "aresample=async=1,";
    }

    if ( $key eq 'audio_delay' ) {
        my $pre_audio_delay_msecs = $argv->{audio_delay_msecs};
        $cmd .=
"adelay=$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs|$pre_audio_delay_msecs,";
    }

    if ( $key eq 'asplit' ) {
        $cmd .= "asplit=" . scalar $argv->{output_count};
        for ( 0 .. ( $argv->{output_count} - 1 ) ) {
            $cmd .= "[aout$_]";
        }
    }

    push @{ $self->{af_options} }, $cmd;
}

sub add_output {
    my $self = shift;
    my ( $key, $argv ) = @_;
    my $cmd = '';

    if ( $key eq 'map_video' ) {
        $cmd .= " -map [vout$self->{output_index}] ";
    }

    if ( $key eq 'map_audio' ) {
        $cmd .= " -map [aout$self->{output_index}] ";
    }

    if ( $key eq 'map_av' ) {
        $cmd .=
          " -map [vout$self->{output_index}] -map [aout$self->{output_index}] ";
    }

    if ( $key eq 'codec_video' ) {
        $cmd .= " -c:v libx264 -x264opts $argv->{x264opts} ";
    }

    if ( $key eq 'codec_audio' ) {
        $cmd .=
          " -c:a libfdk_aac -profile:a aac_he -b:a $argv->{abitrate}" . "k ";
    }

    if ( $key eq 'vsync' ) {
        $cmd .= " -vsync $argv->{vsync_mode} ";
    }

    if ( $key eq 'rtmp' ) {
        $cmd .= " -f flv -y $argv->{url} ";
    }

    if ( $key eq 'rtsp' ) {
        $cmd .= " -f rtsp -y $argv->{url} ";
    }

    if ( $key eq 'file' ) {
        $cmd .=
" -f segment -segment_format flv -segment_time $argv->{o_keyint_secs} -y "
          . $argv->{output_path} . "/"
          . $argv->{channel_id} . "c"
          . $argv->{o_vbitrate} . "k"
          . "%05d.flv";
    }

    push @{ $self->{output_options} }, $cmd;
}

sub render {
    my $self = shift;
    my $cmd  = "";

    # render input
    $cmd .= $_ foreach @{ $self->{input_options} };

    $cmd .= " -filter_complex \"";

    # render video split
    $cmd .= $_ foreach @{ $self->{vf_split_options} };

    # render video filter
    $cmd .= $_ foreach @{ $self->{vf_options} };

    # render audio filter
    $cmd .= $_ foreach @{ $self->{af_options} };

    $cmd .= "\"";

    $cmd .= $_ foreach @{ $self->{output_options} };

    return "$cmd";
}

sub log_output {
	my $self = shift;
	my $argv = {@_};
	$self->{log_path} = $argv->{log_path};
	$self->{logname}  = $argv->{logname};

	my $datestr = strftime( "%Y%m%d", localtime(time) );
	my $log_filename = "$argv->{log_path}/$argv->{logname}" . "_" . $datestr . ".log";

	open my $log_fd, ">>", $log_filename;
	$self->{logfh} = $log_fd;
	print $log_fd "=========== source start at ";
	print $log_fd strftime( "%Y-%m-%d %H:%M:%S", localtime(time) );
	print $log_fd "=========== \n";
}

sub run {
    my $self = shift;
    my ( $log_path, $input_id ) = @_;

    my $cmd = $self->render();

    # log to local file
	if ($self->{log_path}) {
		logpath($self->{log_path});
		log( 'cmd', $cmd );
	}

    while (1) {

        my ( $wtr, $rdr, $err );
        use Symbol 'gensym';
        $err = gensym;
        my $ffmpeg_pid = open3( $wtr, $err, $err, $cmd );

        while (<$err>) {
#killfam 'TERM', $ffmpeg_pid if $_ =~ /stream changed/; 吕超的自动侦测流改变，重启ffmpeg
			my $log_fd = $self->{logfh};
            print $log_fd $_ . "\n";
        }
    }
}

1;

__END__

=head1 NAME

FFmpeg::Syntax::Builder - build complex ffmpeg command easier

=head1 DESCRIPTION

A simple ffmpeg command line untility, make ffmpeg command easier

=head1 SYNOPSIS

  use FFmpeg::Syntax::Builder;
  my $ffmpeg_builder = FFmpeg::Syntax::Builder->new();

  # Support varity of inputs like udp, rtmp, file(localfile), stdin(bmdcapture)
  $ffmpeg_builder->add_input(stdin); # you can assign your sid_port and sid_mode
  $ffmpeg_builder->add_input(udp   => {url  => "udp://ip"});
  $ffmpeg_builder->add_input(ip    => {rtmp => "rtmp://ip"});
  $ffmpeg_builder->add_input(file  => {filepath => $local_file_path});

  # Add watermark file
  $ffmpeg_builder->add_input(watermark  => {filepath => '/tmp/xxx.jpeg'});

  # Support multiple outputs, you should use split 
  # use channel_id to distinguish different channel live
  $ffmpeg_builder->add_vf_split(udp => {channel_id => $channel_id}); # [0:p:$channel_id:0]
  $ffmpeg_builder->add_vf_split(ip  => {channel_id => $channel_id}); # [$channel_id:0]

  # Add watermark position argv, default is top_left, you can assgin top_right/bottom_left/bottom_right
  $ffmpeg_builder->add_vf_split(watermark => {water_positon => 'top_left'})

  # Add YUV format
  $ffmpeg_builder->add_vf_split('format');

  # Add deinterlace, $deinterlace default is "yadif=0:-1"
  $ffmpeg_builder->add_vf_split(deinterlace => $deinterlace);

  # Add split output 
  $ffmpeg_builder->add_vf_split(output_count => $output_count);

  # Add fps (frame per seconds), default is 25
  $ffmpeg_builder->add_vf('fps' => $fps);

  # Add scale 
  $ffmpeg_builder->add_vf('scale' => {width => $width, height => $height});

  # Add vf 
  $ffmpeg_builder->add_vf(vf => $vf_string);

  # Add drawtext, you must assgin ttf font file, logo_text, fontsize 
  $ffmpeg_builder->add_vf( 'drawtext' => {
								fontfile  => '/data1/sue/rc/san_serif.ttf',
				  				logo_text => $logo_text,
				  				fontsize  => $o_fontsize });

  # Add set dar
  $ffmpeg_builder->add_vf(dar => {width => $width, height => $height} );
  
  # Add output tag
  $ffmpeg_builder->add_vf('output_tag');

  # Add Audio

  # Add udp or ip, assgin channel_id
  $ffmpeg_builder->add_vf_split(udp => {channel_id => $channel_id}); # [0:p:$channel_id:0]
  $ffmpeg_builder->add_vf_split(ip  => {channel_id => $channel_id}); # [$channel_id:0]

  # Add mono
  $ffmpeg_builder->add_af('mono');

  # Add volume, turn volume up or down, default is AUTO
  $ffmpeg_builder->add_af('volume');

  # Add async to async video and audio
  $ffmpeg_builder->add_af('async');

  # Add audio delay 
  $ffmpeg_builder->add_af(audio_delay => {audio_delay_msecs => 15});

  # Add output count
  $ffmpeg_builder->add_af(output_count => 1);

  # Add output
  # Add map
  $ffmepg_builder->add_output('map_av');
  
  # Add codec video x264opts
  $ffmpeg_builder->add_output(codec_video => {x264opts => $x264opts});

  # Add vsync 
  $ffmpeg_builder->add_output('vsync' => { vsync_mode => 2 });

  # Add codec audio 
  $ffmpeg_builder->add_output('codec_audio' => { abitrate => "libfdk_aac -b:a 16k" });

  # Add output type, support rtmp/rtsp/file(localfile)
  $ffmpeg_builder->add_output('rtmp' => { url => $rtmp_url });
  $ffmpeg_builder->add_output('rtmp' => { url => $rtsp_url });

  # Assgin the log file. If you do not assgin the logfile, default is log to stderr
  $ffmpeg_builder->log_output(logpath => '/tmp', logname => 'test')

  # Run the command
  $ffmpeg_builder->run();

=head1 METHODS

=head2 add_input()

Assgin the input type which you want

=head2 add_vf_split()

When you have multiple outputs, you must split multiple outpus

=head2 add_vf()

Assgin the codec videu

=head2 add_af()

Assgin the codec audio

=head2 add_output()

Assgin the output type which you want

=head2 log_output()

Print ffmpeg command output to logfile 

=head2 run()

Run the command

=head1 AUTHOR

Written by WayneZhou, cumtxhzyyatgmail.com
L<http://blog.cnperler.com>

=head1 COPYRIGHT

Copyright (c) 2015 WayneZhou. This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

