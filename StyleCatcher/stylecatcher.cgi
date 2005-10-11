#!/usr/local/bin/perl -w

use strict;
#use lib ($0 =~ m!(.*[/\\])! ? $1 . 'lib' : 'lib'), ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : $1 ? "$1../../lib" : "../../lib");
use lib "lib", ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : "../../lib"); 
use MT::Bootstrap App => 'StyleCatcher';
