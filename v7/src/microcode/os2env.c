/* -*-C-*-

$Id: os2env.c,v 1.6 1995/04/28 07:04:58 cph Exp $

Copyright (c) 1994-95 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. */

#include "scheme.h"
#include "os2.h"
#include "osenv.h"
#include <time.h>
#include <sys\types.h>

#ifdef __IBMC__

#include <sys\timeb.h>

#else /* not __IBMC__ */
#ifdef __GCC2__

#include <errno.h>
#include <sys/times.h>

#endif /* __GCC2__ */
#endif /* not __IBMC__ */

static void initialize_real_time_clock (void);
static double get_real_time_clock (void);

static void initialize_timer (void);
static void timer_thread (void *);
static void handle_timer_event (msg_t *);

void
OS2_initialize_environment (void)
{
  initialize_real_time_clock ();
  initialize_timer ();
}

time_t
OS_encoded_time (void)
{
  time_t t = (time (0));
  if (t < 0)
    OS2_error_system_call (errno, syscall_time);
  return (t);
}

void
OS_decode_time (time_t t, struct time_structure * buffer)
{
  struct tm * ts = (localtime (&t));
  if (ts == 0)
    OS2_error_system_call (errno, syscall_localtime);
  (buffer -> year) = ((ts -> tm_year) + 1900);
  (buffer -> month) = ((ts -> tm_mon) + 1);
  (buffer -> day) = (ts -> tm_mday);
  (buffer -> hour) = (ts -> tm_hour);
  (buffer -> minute) = (ts -> tm_min);
  (buffer -> second) = (ts -> tm_sec);
  (buffer -> daylight_savings_time) = (ts -> tm_isdst);
  {
    /* In localtime() encoding, 0 is Sunday; in ours, it's Monday. */
    int wday = (ts -> tm_wday);
    (buffer -> day_of_week) = ((wday == 0) ? 6 : (wday - 1));
  }
}  

time_t
OS_encode_time (struct time_structure * buffer)
{
  struct tm ts;
  (ts . tm_year) = ((buffer -> year) - 1900);
  (ts . tm_mon) = ((buffer -> month) - 1);
  (ts . tm_mday) = (buffer -> day);
  (ts . tm_hour) = (buffer -> hour);
  (ts . tm_min) = (buffer -> minute);
  (ts . tm_sec) = (buffer -> second);
  (ts . tm_isdst) = (buffer -> daylight_savings_time);
  {
    time_t t = (mktime (&ts));
    if (t < 0)
      OS2_error_system_call (errno, syscall_mktime);
    return (t);
  }
}

long
OS2_timezone (void)
{
  return (_timezone);
}

int
OS2_daylight_savings_p (void)
{
  return (_daylight);
}

static double initial_rtc;

static void
initialize_real_time_clock (void)
{
  initial_rtc = (get_real_time_clock ());
}

double
OS_real_time_clock (void)
{
  return ((get_real_time_clock ()) - initial_rtc);
}

static double
get_real_time_clock (void)
{
#ifdef __IBMC__
  struct timeb rtc;
  _ftime (&rtc);
  return ((((double) (rtc . time)) * 1000.0) + ((double) (rtc . millitm)));
#else /* not __IBMC__ */
#ifdef __GCC2__
  struct tms rtc;
  times (&rtc);
  return (((double) (rtc . tms_utime)) * (1000.0 / ((double) CLK_TCK)));
#endif /* __GCC2__ */
#endif /* not __IBMC__ */
}

double
OS_process_clock (void)
{
  /* This must not signal an error in normal use. */
  return (OS_real_time_clock ());
}

static HEV timer_event;
static int timer_handle_valid;
static HTIMER timer_handle;
TID OS2_timer_tid;

static void
initialize_timer (void)
{
  timer_event = (OS2_create_event_semaphore (0, 1));
  timer_handle_valid = 0;
  OS2_timer_tid = (OS2_beginthread (timer_thread, 0, 0));
}

static void
timer_thread (void * arg)
{
  EXCEPTIONREGISTRATIONRECORD registration;
  (void) OS2_thread_initialize ((&registration), QID_NONE);
  while (1)
    {
      ULONG count = (OS2_reset_event_semaphore (timer_event));
      while (count > 0)
	{
	  OS2_send_message (OS2_interrupt_qid,
			    (OS2_create_message (mt_timer_event)));
	  count -= 1;
	}
      (void) OS2_wait_event_semaphore (timer_event, 1);
    }
}

void
OS_real_timer_set (clock_t first, clock_t interval)
{
  /* **** No support for (first != interval), but runtime system never
     does that anyway.  */
  OS_real_timer_clear ();
  if (interval != 0)
    {
      STD_API_CALL (dos_start_timer, (interval,
				      ((HSEM) timer_event),
				      (&timer_handle)));
      timer_handle_valid = 1;
    }
  else if (first != 0)
    {
      STD_API_CALL (dos_async_timer, (first,
				      ((HSEM) timer_event),
				      (&timer_handle)));
      timer_handle_valid = 1;
    }
}

void
OS_real_timer_clear (void)
{
  if (timer_handle_valid)
    {
      STD_API_CALL (dos_stop_timer, (timer_handle));
      timer_handle_valid = 0;
    }
  (void) OS2_reset_event_semaphore (timer_event);
}

void
OS_process_timer_set (clock_t first, clock_t interval)
{
  OS2_error_unimplemented_primitive ();
}

void
OS_process_timer_clear (void)
{
}

void
OS_profile_timer_set (clock_t first, clock_t interval)
{
  OS2_error_unimplemented_primitive ();
}

void
OS_profile_timer_clear (void)
{
}

static size_t current_dir_path_size = 0;
static char * current_dir_path = 0;

const char *
OS_working_dir_pathname (void)
{
  ULONG drive_number;
  {
    ULONG drive_map;
    STD_API_CALL (dos_query_current_disk, ((&drive_number), (&drive_map)));
  }
  if ((current_dir_path_size == 0) || (current_dir_path == 0))
    {
      current_dir_path_size = 1024;
      current_dir_path = (OS_malloc (current_dir_path_size));
    }
  while (1)
    {
      ULONG size = (current_dir_path_size - 3);
      {
	APIRET rc =
	  (dos_query_current_dir
	   (drive_number, (current_dir_path + 3), (&size)));
	if (rc == NO_ERROR)
	  break;
	if (rc != ERROR_BUFFER_OVERFLOW)
	  OS2_error_system_call (rc, syscall_dos_query_current_dir);
      }
      do
	current_dir_path_size *= 2;
      while ((current_dir_path_size - 3) < size);
      OS_free (current_dir_path);
      current_dir_path = (OS_malloc (current_dir_path_size));
    }
  (current_dir_path[0]) = ('a' + drive_number - 1);
  (current_dir_path[1]) = ':';
  (current_dir_path[2]) = '\\';
  return (current_dir_path);
}

void
OS_set_working_dir_pathname (const char * name)
{
  extern char * OS2_remove_trailing_backslash (const char *);
  unsigned int length;
  name = (OS2_remove_trailing_backslash (name));
  length = (strlen (name));
  if ((length >= 2) && ((name[1]) == ':'))
    {
      STD_API_CALL
	(dos_set_default_disk,
	 ((name[0]) - ((islower (name[0])) ? 'a' : 'A') + 1));
      name += 2;
      length -= 2;
    }
  STD_API_CALL (dos_set_current_dir, ((length == 0) ? "\\" : name));
}
