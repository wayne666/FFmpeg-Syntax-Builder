use strict;
use warnings;

use Test::More tests => 1;
use Data::Dumper;
use lib '../lib';
use FFmpeg::Syntax::Builder;

my $ffmpeg_builder = FFmpeg::Syntax::Builder->new();

$ffmpeg_builder->add_vf( 'fps' => 25 );

$ffmpeg_builder->add_vf(
	'scale' => { width => 1080, height => 720 } );

$ffmpeg_builder->add_vf( vf       => 'pp=de' );

$ffmpeg_builder->add_vf(
	'drawtext' => {
		fontfile  => '/tmp/test.ttf',
		logo_text => 'test',
		fontsize  => 14,
	}
);

$ffmpeg_builder->add_vf(
	'dar' => { width => 16, height => 9 } );

$ffmpeg_builder->add_vf( 'output_tag' );    # [vout$_]

my $expected = "[vtmp10]fps=25,scale=1080:720,pp=de[vtmp20],[vtmp20] drawtext=fontfile=/tmp/test.ttf:text='test':x=(w-text_w)*lte(mod(t\\,12)\\,6):y=h-text_h-1:fontsize=14:fontcolor=white\@0.8:shadowx=1:shadowy=1:enable=lte(mod(t\\,6)\\,5),setdar=dar=16/9 [vout0],";

my $cmd;
$cmd .= $_ foreach (@{$ffmpeg_builder->{vf_options}});

is( $cmd, $expected, "vf build" );

