#!/bin/csh -f
###
###	$Id: ultrix.m4,v 1.6 1993/06/24 07:32:21 gjr Exp $
###
###	Copyright (c) 1989-1993 Massachusetts Institute of Technology
###
####	Postprocessing to make m4 work correctly under Ultrix & BSD.

if ($#argv == 0) then
  sed -e '/^#/D' | m4 | sed -e 's/@/$/g' -e 's/^$//'
else
  set tmpfil = "m4.tmp"
  set seen_input = 0
  rm -f "$tmpfil"
  
  while ($#argv != 0)
    if ("$argv[1]" == "-P") then
      echo "$argv[2]" >> "$tmpfil"
      shift
    else
      set seen_input = 1
      sed -e '/^#/D' < "$argv[1]" >> "$tmpfil"
    endif
    shift
  end
  if ($seen_input == 0) then
    sed -e '/^#/D' >> "$tmpfil"
  endif
  m4 < "$tmpfil" | sed -e 's/@/$/g' -e 's/^$//'
  rm -f "$tmpfil"
endif
