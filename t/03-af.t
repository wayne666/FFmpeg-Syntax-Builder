use strict;
use warnings;

use Test::More tests => 1;
use Data::Dumper;
use lib '../lib';
use FFmpeg::Syntax::Builder;

my $ffmpeg_builder = FFmpeg::Syntax::Builder->new();


$ffmpeg_builder->add_af( ip => { i_map => 5 } );

$ffmpeg_builder->add_af('mono');

$ffmpeg_builder->add_af('volume');

$ffmpeg_builder->add_af('async');

$ffmpeg_builder->add_af(
	audio_delay => { audio_delay_msecs => 100 } );

$ffmpeg_builder->add_af(
	'asplit' => { output_count => 1 } );

my $expected = "[5:a:0]pan=1:c0<c0+c1,ebur128=metadata=1,aresample=async=1,adelay=100|100|100|100|100|100|100|100|100|100|100|100|100|100|100|100,asplit=1[aout0]";

my $cmd;
$cmd .= $_ foreach (@{$ffmpeg_builder->{af_options}});


is( $cmd, $expected, "af build" );

