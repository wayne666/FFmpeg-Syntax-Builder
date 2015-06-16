use strict;
use warnings;

use Test::More tests => 1;
use FFmpeg::Syntax::Builder;

my $builder = FFmpeg::Syntax::Builder->new();
$builder->add_input(
    type   => "uri",
    live   => 1,
    source => "rtmp://123123",
);
$builder->add_input(
    type   => "uri",
    live   => 1,
    source => "rtmp://12223333333",
);
$builder->add_input(
    type   => "stdin",
    live   => 1,
    source => "bmdcaptrue",
);

my $got = $builder->render();
my $expected =
"bmdcaptrue | /usr/local/bin/ffmpeg -re  -i -  -re  -i rtmp://123123 -re  -i rtmp://12223333333";

is( $got, $expected, "input build" );

