use strict;
use warnings;

use Test::More tests => 1;
use Data::Dumper;
use lib '../lib';
use FFmpeg::Syntax::Builder;

my $ffmpeg_builder = FFmpeg::Syntax::Builder->new();

$ffmpeg_builder->add_output('map_av');

$ffmpeg_builder->add_output( 'codec_video',
	{ x264opts => "keyint=123:min-keyint=20" } );

$ffmpeg_builder->add_output( 'codec_audio',
	{ abitrate => 64 } );

$ffmpeg_builder->add_output( 'vsync',
	{ vsync_mode => 2 } );

$ffmpeg_builder->add_output( 'rtmp', { url => 'rtmp://127.0.0.1/live/test' } );

my $expected = " -map [vout0] -map [aout0]  -c:v libx264 -x264opts keyint=123:min-keyint=20  -c:a libfdk_aac -profile:a aac_he -b:a 64k  -vsync 2  -f flv -y rtmp://127.0.0.1/live/test ";

my $cmd;
$cmd .= $_ foreach (@{$ffmpeg_builder->{output_options}});


is( $cmd, $expected, "output build" );

