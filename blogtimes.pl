# ---------------------------------------------------------------------------
# BlogTimes
# A Plugin for Movable Type
#
# Release 1.0
# 
# Author: Nilesh Chaudhari
# http://nilesh.org/mt/blogtimes/
# ---------------------------------------------------------------------------
#
# Copyright (c) 2002 Nilesh Chaudhari
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ---------------------------------------------------------------------------

use strict;
use MT::Template::Context;
use MT::Util qw(days_in offset_time);
use GD;	

MT::Template::Context->add_container_tag(BlogTimes => \&BlogTimes);
MT::Template::Context->add_tag(BlogTimesWidth => \&BlogTimesWidth);
MT::Template::Context->add_tag(BlogTimesHeight => \&BlogTimesHeight);
MT::Template::Context->add_tag(BlogTimesFilename => \&BlogTimesFilename);
MT::Template::Context->add_tag(BlogTimesFullFilename => \&BlogTimesFullFilename);
MT::Template::Context->add_tag(BlogTimesFileURL => \&BlogTimesFileURL);

sub BlogTimes {
  my ($ctx, $args) = @_;
  #                                      Default Values
  my $chart_type = $args->{style}         || 'bar';
  my $blog = $ctx->stash('blog');
  my $site_path = $blog->site_path . '/';
  my $site_url = $blog->site_url . '/';
  my $width = $args->{width}             || 400;
  my $height = $args->{height}           || 30;
  my $period = $args->{month} || ((((gmtime)[5]+1900)*100)+(gmtime)[4]+1);
  my $linecolor = $args->{linecolor}     || '#FFFFFF';
  my $textcolor = $args->{textcolor}     || '#757575';
  my $fillcolor = $args->{fillcolor}     || '#757575';
  my $bordercolor = $args->{bordercolor} || '#757575';
  my $pad = $args->{padding}             || 5;
  my $basename = $args->{name}           || 'blogtimes';
  my $show_text = $args->{show_text}     || 'on';
  my $save_dir = $args->{save_dir}.'/'   || '';

  my (@entry_times,@entries, $entry);
  
  # Get entries for specified month
  my $month = substr($period,4,2);
  my $year = substr($period,0,4);
  my $date_start = sprintf("%04d%02d%02d%06d",$year,$month,'01','000000');
  my $date_end = sprintf("%04d%02d%02d%06d",$year,$month,
       days_in($month,$year),'235959');
  @entries = MT::Entry->load({ blog_id => $ctx->stash('blog_id'), 
                        created_on => [ $date_start, $date_end ] ,                
                        status => MT::Entry::RELEASE() },
	                { range => { created_on => 1 }}
	      );
  foreach $entry (@entries) {
    push @entry_times, substr($entry->created_on, 8, 4);
  }
  # Actual drawing  
  my $txtpad = ($show_text eq 'off')? 0: gdTinyFont->height;
  my $scale_width = $width+($pad*2);
  my $scale_height = $height+($pad*2)+$txtpad+$txtpad;
  my $img = GD::Image->new($scale_width,$scale_height);
  my $white = $img->colorAllocate(255,255,255);
  $linecolor = $img->colorAllocate(&hex2rgb($linecolor));
  $textcolor = $img->colorAllocate(&hex2rgb($textcolor));
  $fillcolor = $img->colorAllocate(&hex2rgb($fillcolor));
  $bordercolor = $img->colorAllocate(&hex2rgb($bordercolor));
  $img->transparent($white);
  my $line_y1 = $pad+$txtpad;
  my $line_y2 = $pad+$txtpad+$height;
  $img->rectangle(0,0,$scale_width-1,$scale_height-1,$bordercolor);
  $img->filledRectangle($pad,$line_y1,$pad+$width,$line_y2,$fillcolor);
  my ($line_x,$i);
  foreach $i (@entry_times) {
    $line_x = $pad + (round((to_minutes($i)/1440)*$width));
    $img->line($line_x,$line_y1,$line_x,$line_y2,$linecolor);
  }
  # Shut off text if width is too less.
  if ($show_text eq 'on') {
  if ($width >= 100) {
    my $ruler_y = $pad+$txtpad+$height+2;
    my $ruler_x;
    for ($i = 0; $i <= 23; $i+=2) {
      $ruler_x = $pad + round($i*$width/24);
      $img->string(gdTinyFont,$ruler_x,$ruler_y,"$i",$textcolor);
    }
    $img->string(gdTinyFont, $pad+$width-2,$ruler_y,"0", $textcolor);
    my $caption_x = $pad;
    my $caption_y = $pad-1;
    my $caption = "B L O G T I M E S   ".&month2str($month)." $year";
    $img->string(gdTinyFont,$caption_x,$caption_y,$caption,$textcolor);
  } else {
    my $ruler_y = $pad+$txtpad+$height+2;
    my $ruler_x;
    for ($i = 0; $i <= 23; $i+=6) {
      $ruler_x = $pad + round($i*$width/24);
      $img->string(gdTinyFont,$ruler_x,$ruler_y,"$i",$textcolor);
    }
    $img->string(gdTinyFont, $pad+$width-2,$ruler_y,"0", $textcolor);
    my $caption_x = $pad;
    my $caption_y = $pad-1;
    my $caption = "$month $year";
    $img->string(gdTinyFont,$caption_x,$caption_y,$caption,$textcolor);
  }
  }
  # Save Image file
  my $image_file = "$site_path$save_dir$basename.png";
  open(CHART, ">$image_file") or  $ctx->error("Cannot open file for writing");
  binmode CHART;
  print CHART $img->png;
  close CHART;
  
  my $tokens = $ctx->stash('tokens');
  my $builder = $ctx->stash('builder');
    
  local $ctx->{__stash}{BlogTimesWidth} = $scale_width;
  local $ctx->{__stash}{BlogTimesHeight} = $scale_height;
  local $ctx->{__stash}{BlogTimesFilename} = "$basename.png";
  local $ctx->{__stash}{BlogTimesFullFilename} = $image_file;
  local $ctx->{__stash}{BlogTimesFileURL} = "$site_url$save_dir$basename.png";    
  
  defined(my $out = $builder->build($ctx, $tokens)) 
    or return $ctx->error($builder->errstr);
  $out;
}

sub hex2rgb {
 $_[0] =~ s/^#//;
 return undef unless ($_[0] =~ /[0-9a-fA-F]{6}/);
 return (hex(substr($_[0],0,2)),hex(substr($_[0],2,2)),hex(substr($_[0],4,2)));
}
sub round      { return sprintf("%.0f",$_[0]); }
sub to_minutes { return (((substr($_[0],0,2))*60)+(substr($_[0],2,2))); }
sub month2str  { return ('JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
  'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER')[$_[0]-1]; }
sub BlogTimesWidth        { $_[0]->stash('BlogTimesWidth')        || ''; }
sub BlogTimesHeight       { $_[0]->stash('BlogTimesHeight')       || ''; }
sub BlogTimesFilename     { $_[0]->stash('BlogTimesFilename')     || ''; }
sub BlogTimesFullFilename { $_[0]->stash('BlogTimesFullFilename') || ''; }
sub BlogTimesFileURL      { $_[0]->stash('BlogTimesFileURL')      || ''; }

1;