use ExtUtils::MakeMaker;
use strict;

WriteMakefile( 
               'NAME'           => 'JAC::OCS::Config',
               'VERSION'        => '0.01',
               'PREREQ_PM'      => {
                                    'Test::More' => 0,
                                   },
               'dist'           => { COMPRESS => "gzip -9f"},
               ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
               ( ABSTRACT  => 'JCMT OCS Configuration parsing',
                 AUTHOR         => 'Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>') : ()),
             );
