/* -*-C-*-

$Id: dosenv.c,v 1.10 1999/01/02 06:11:34 cph Exp $

Copyright (c) 1992-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "msdos.h"
#include "osenv.h"
#include <stdlib.h>

time_t
DEFUN_VOID (OS_encoded_time)
{
  time_t t;
  STD_UINT_SYSTEM_CALL (syscall_time, t, (DOS_time (0)));
  return (t);
}

void
DEFUN (OS_decode_time, (t, buffer), time_t t AND struct time_structure * buffer)
{
  struct tm * ts;
  STD_PTR_SYSTEM_CALL (syscall_localtime, ts, (DOS_localtime (&t)));
  (buffer -> year) = ((ts -> tm_year) + 1900);
  (buffer -> month) = ((ts -> tm_mon) + 1);
  (buffer -> day) = (ts -> tm_mday);
  (buffer -> hour) = (ts -> tm_hour);
  (buffer -> minute) = (ts -> tm_min);
  (buffer -> second) = (ts -> tm_sec);
  (buffer -> daylight_savings_time) = (ts -> tm_isdst);
  /* I'm assuming that `timezone' is implemented by the C library;
     this might need conditionalization.  -- cph */
  (buffer -> time_zone) = timezone;
  {
    /* In localtime() encoding, 0 is Sunday; in ours, it's Monday. */
    int wday = (ts -> tm_wday);
    (buffer -> day_of_week) = ((wday == 0) ? 6 : (wday - 1));
  }
}

time_t
DEFUN (OS_encode_time ,(buffer), struct time_structure * buffer)
{
  time_t t;
  struct tm ts_s, * ts;
  ts = &ts_s;
  (ts -> tm_year) = ((buffer -> year) - 1900);
  (ts -> tm_mon) = ((buffer -> month) - 1);
  (ts -> tm_mday) = (buffer -> day);
  (ts -> tm_hour) = (buffer -> hour);
  (ts -> tm_min) = (buffer -> minute);
  (ts -> tm_sec) = (buffer -> second);
  (ts -> tm_isdst) = (buffer -> daylight_savings_time);
  STD_UINT_SYSTEM_CALL (syscall_mktime, t, (DOS_mktime (ts)));
  /* mktime assumes its argument is local time, and converts it to
     UTC; if the specified time zone is different, adjust the result.  */
  if (((buffer -> time_zone) != INT_MAX)
      && ((buffer -> time_zone) != timezone))
    t = ((t - timezone) + (buffer -> time_zone));
  return (t);
}

double
DEFUN_VOID (OS_real_time_clock)
{
  /* Jump through hoops because `clock()' wraps around to zero after
     one day and `time()' has at best resolution of one second.  */
  return
    (((((double) (((long) (OS_encoded_time ())) / 60L)) * 60.0)
      + (((double) (((long) (clock ())) % (60L * ((long) CLOCKS_PER_SEC))))
	 / ((double) CLOCKS_PER_SEC)))
     * 1000.0);
}

double
DEFUN_VOID (OS_process_clock)
{
  /* This must not signal an error in normal use. */
  return (OS_real_time_clock ());
}

/* Timer adjustments */
#define PC_TIMER_TICKS_PER_SECOND	(18.2)
/* This should work out to about 55 */
#define PC_MILLISECONDS_PER_TIMER_TICK  \
  ((long) ((1000.0/PC_TIMER_TICKS_PER_SECOND)+0.5))

static unsigned long
DEFUN (ms_to_ticks, (clocks), clock_t clocks)
{ ldiv_t ticks;
  unsigned long result;

  ticks = ldiv((long) clocks, PC_MILLISECONDS_PER_TIMER_TICK);

  result = ((ticks.rem >= (PC_MILLISECONDS_PER_TIMER_TICK/2)) ?
   	    (ticks.quot + 1) : (ticks.quot));
  return (result == 0) ? 1 : result;  
}
  
void
DEFUN (OS_process_timer_set, (first, interval),
       clock_t first AND
       clock_t interval)
{ extern volatile unsigned long scm_itimer_counter, scm_itimer_reload;
  /* Convert granularity to 1/18.2 seconds */

  scm_itimer_counter = ms_to_ticks(first);
  scm_itimer_reload  = ms_to_ticks(interval);
  
  return;  
}

void
DEFUN_VOID (OS_process_timer_clear)
{
  scm_itimer_reload = scm_itimer_counter = 0;
  return;
}

void
DEFUN (OS_profile_timer_set, (first, interval),
       clock_t first AND
       clock_t interval)
{
  error_unimplemented_primitive ();
}

void
DEFUN_VOID (OS_profile_timer_clear)
{
  return;
}

void
DEFUN (OS_real_timer_set, (first, interval),
       clock_t first AND
       clock_t interval)
{
  OS_process_timer_set (first, interval);
}

void
DEFUN_VOID (OS_real_timer_clear)
{
  OS_process_timer_clear();
  return;
}

void
DEFUN_VOID (DOS_initialize_environment)
{
  return;
}

static size_t current_dir_path_size = 0;
static char * current_dir_path = 0;

CONST char *
DEFUN_VOID (OS_working_dir_pathname)
{
  if (current_dir_path) {
    return (current_dir_path);
  }
  if (current_dir_path_size == 0)
    {
      current_dir_path = (DOS_malloc (1024));
      if (current_dir_path == 0)
	error_system_call (ENOMEM, syscall_malloc);
      current_dir_path_size = 1024;
    }
  while (1)
    {
      if ((DOS_getcwd (current_dir_path, current_dir_path_size)) != 0)
      { strlwr(current_dir_path);
	return (current_dir_path);
      }
#ifdef ERANGE
      if (errno != ERANGE)
	error_system_call (errno, syscall_getcwd);
#endif      
      current_dir_path_size *= 2;
      {
	char * new_current_dir_path =
	  (DOS_realloc (current_dir_path, current_dir_path_size));
	if (new_current_dir_path == 0)
	  /* ANSI C requires `path' to be unchanged -- we may have to
	     discard it for systems that don't behave thus. */
	  error_system_call (ENOMEM, syscall_realloc);
	current_dir_path = new_current_dir_path;
      }
    }
}

void
DEFUN (OS_set_working_dir_pathname, (name), char * name)
{ char filename[128], drive[3];
  int drive_number;
  size_t name_size = strlen (name);
  
  drive_number = dos_split_filename(name, drive, filename);
  dos_set_default_drive(drive_number);
  STD_VOID_SYSTEM_CALL (syscall_chdir, (DOS_chdir (filename)));

  while (1) {
    if (name_size < current_dir_path_size) {
      strcpy(current_dir_path, name);
      return;
    } 
    current_dir_path_size *= 2;
    {
      char * new_current_dir_path =
	(DOS_realloc (current_dir_path, current_dir_path_size));
      if (new_current_dir_path == 0)
	error_system_call (ENOMEM, syscall_realloc);
      current_dir_path = new_current_dir_path;
    }
  }
}
