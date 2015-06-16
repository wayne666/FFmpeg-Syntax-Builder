use 5.018002;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'FFmpeg::Syntax::Builder',
    VERSION_FROM      => 'lib/FFmpeg/Syntax/Builder.pm', 
    PREREQ_PM         => {}, 
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/FFmpeg/Syntax/Builder.pm', 
       AUTHOR         => 'sss') : ()),
);
