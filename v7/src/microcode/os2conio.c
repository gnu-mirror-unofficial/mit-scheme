/* -*-C-*-

$Id: os2conio.c,v 1.5 1995/01/05 23:39:57 cph Exp $

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

#define USE_PMCON
/* #define USE_VIO */
/* #define USE_PMIO */

#include "os2.h"

#ifdef USE_PMCON

extern void OS2_initialize_pm_console (void);
extern int  OS2_pm_console_getch (void);
extern void OS2_pm_console_write (const char *, size_t);

#else
#ifdef USE_PMIO

#include <pmio.h>

#endif
#endif

#ifdef USE_PMCON
#define getch OS2_pm_console_getch
#else
#ifndef USE_PMIO
static int getch (void);
#endif
#endif

static void console_thread (void *);
static void grab_console_lock (void);
static void release_console_lock (void);

static void process_input_char (char);
static void do_rubout (void);
static void add_to_line (char);
static void do_newline (void);
static void do_self_insert (char);
static void add_char_to_line_buffer (char);
static void finish_line (void);
static void send_char (char);
static void send_readahead (msg_t *);
static void handle_console_interrupt (msg_t *);

static void console_operator
  (Tchannel, chop_t, choparg_t, choparg_t, choparg_t);;
static void flush_input (void);
static void console_input_buffered (Tchannel, int, int *);
static void console_output_cooked (Tchannel, int, int *);

static void write_char (char, int);
static void write_output (const char *, size_t, int);
static void write_output_1 (const char *, const char *);
static unsigned int char_output_length (char);

static HMTX console_lock;
static int input_buffered_p;
static int output_cooked_p;
static qid_t console_writer_qid;
static channel_context_t * console_context;
static readahead_buffer_t * line_buffer;

void
OS2_initialize_console (void)
{
#ifdef USE_PMCON
  OS2_initialize_pm_console ();
#else
#ifdef USE_PMIO
  pmio_fontspec = "6.System VIO";
  set_width (80);
  set_height (40);
  start_pmio ();
#endif
#endif
  console_lock = (OS2_create_mutex_semaphore (0, 0));
  input_buffered_p = 1;
  output_cooked_p = 1;
  console_context = (OS2_make_channel_context ());
  OS2_open_qid ((CHANNEL_CONTEXT_READER_QID (console_context)),
		OS2_scheme_tqueue);
  console_writer_qid = (CHANNEL_CONTEXT_WRITER_QID (console_context));
  OS2_open_qid (console_writer_qid, (OS2_make_std_tqueue ()));
  (CHANNEL_CONTEXT_FIRST_READ_P (console_context)) = 0;
  (CHANNEL_CONTEXT_TID (console_context))
    = (OS2_beginthread (console_thread, 0, 0x4000));
}

static void
console_thread (void * arg)
{
  grab_console_lock ();
  line_buffer = (OS2_make_readahead_buffer ());
  release_console_lock ();
  (void) OS2_thread_initialize (console_writer_qid);
  while (1)
    {
      int c = (getch ());
      if (c == EOF)
	break;
      {
	int code = (OS2_keyboard_interrupt_handler (c));
	if (code == '\0')
	  process_input_char (c);
	else
	  {
	    msg_t * message = (OS2_create_message (mt_console_interrupt));
	    (SM_CONSOLE_INTERRUPT_CODE (message)) = code;
	    OS2_send_message (OS2_interrupt_qid, message);
	    /* Flush buffers only for certain chars? */
	    flush_input ();
	    if (c == '\a')
	      write_char ('\a', 0);
	  }
      }
    }
  OS2_endthread ();
}

#if ((!defined(USE_PMCON)) && (!defined(USE_PMIO)))
static int
getch (void)
{
  while (1)
    {
#ifdef USE_VIO
      KBDKEYINFO info;
      XTD_API_CALL
	(kbd_char_in, ((&info), IO_WAIT, 0),
	 {
	   if (rc == ERROR_KBD_INVALID_HANDLE)
	     return (EOF);
	 });
      if ((info . fbStatus) == 0x40)
	return (info . chChar);
#else
      int c = (_getch ());
      if (c == EOF)
	return (EOF);
      else if ((c == 0) || (c == 0xe0))
	{
	  /* Discard extended keycodes. */
	  if ((_getch ()) == EOF)
	    return (EOF);
	}
      else
	return (c);
#endif
    }
}
#endif /* not USE_PMIO */

static void
grab_console_lock (void)
{
  OS2_request_mutex_semaphore (console_lock);
}

static void
release_console_lock (void)
{
  OS2_release_mutex_semaphore (console_lock);
}

static void
process_input_char (char c)
{
  if (!input_buffered_p)
    send_char (c);
  else switch (c)
    {
    case '\b':
    case '\177':
      do_rubout ();
      break;
    case '\r':
      do_self_insert ('\r');
      do_self_insert ('\n');
      finish_line ();
      break;
    default:
      do_self_insert (c);
      break;
    }
}

static void
do_self_insert (char c)
{
  add_char_to_line_buffer (c);
  write_char (c, 1);
}

static void
add_char_to_line_buffer (char c)
{
  grab_console_lock ();
  OS2_readahead_buffer_insert (line_buffer, c);
  release_console_lock ();
}

static void
do_rubout (void)
{
  grab_console_lock ();
  if (OS2_readahead_buffer_emptyp (line_buffer))
    {
      release_console_lock ();
      write_char ('\a', 0);
      return;
    }
  {
    unsigned int n
      = (char_output_length (OS2_readahead_buffer_rubout (line_buffer)));
    unsigned int i;
    release_console_lock ();
    for (i = 0; (i < n); i += 1)
      write_char ('\b', 0);
    for (i = 0; (i < n); i += 1)
      write_char (' ', 0);
    for (i = 0; (i < n); i += 1)
      write_char ('\b', 0);
  }
}

static void
finish_line (void)
{
  msg_list_t * messages;
  grab_console_lock ();
  messages = (OS2_readahead_buffer_read_all (line_buffer));
  release_console_lock ();
  while (messages != 0)
    {
      msg_list_t * element = messages;
      messages = (messages -> next);
      send_readahead (element -> message);
      OS_free (element);
    }
}

static void
send_char (char c)
{
  msg_t * message = (OS2_make_readahead ());
  (SM_READAHEAD_SIZE (message)) = 1;
  ((SM_READAHEAD_DATA (message)) [0]) = c;
  send_readahead (message);
}

static void
send_readahead (msg_t * message)
{
  OS2_send_message (console_writer_qid, message);
  OS2_wait_for_readahead_ack (console_writer_qid);
}

void
OS2_initialize_console_channel (Tchannel channel)
{
  (CHANNEL_OPERATOR_CONTEXT (channel)) = console_context;
  (CHANNEL_OPERATOR (channel)) = console_operator;
}

static void
console_operator (Tchannel channel, chop_t operation,
		  choparg_t arg1, choparg_t arg2, choparg_t arg3)
{
  switch (operation)
    {
    case chop_read:
      (* ((long *) arg3))
	= (OS2_channel_thread_read
	   (channel, ((char *) arg1), ((size_t) arg2)));
      break;
    case chop_write:
      write_output (((const char *) arg1), ((size_t) arg2), output_cooked_p);
      (* ((long *) arg3)) = ((size_t) arg2);
      break;
    case chop_close:
    case chop_output_flush:
    case chop_output_drain:
      break;
    case chop_input_flush:
      flush_input ();
      break;
    case chop_input_buffered:
      console_input_buffered (channel, ((int) arg1), ((int *) arg2));
      break;
    case chop_output_cooked:
      console_output_cooked (channel, ((int) arg1), ((int *) arg2));
      break;
    default:
      OS2_logic_error ("Unknown operation for console.");
      break;
    }
}

static void
flush_input (void)
{
  msg_list_t * messages;
  grab_console_lock ();
  messages = (OS2_readahead_buffer_read_all (line_buffer));
  release_console_lock ();
  while (messages != 0)
    {
      msg_list_t * element = messages;
      messages = (messages -> next);
      OS2_destroy_message (element -> message);
      OS_free (element);
    }
}

static void
console_input_buffered (Tchannel channel, int new, int * pold)
{
  if (new < 0)
    (* pold) = input_buffered_p;
  else
    {
      int old = input_buffered_p;
      input_buffered_p = new;
      if (old && (!new))
	flush_input ();
    }
}

static void
console_output_cooked (Tchannel channel, int new, int * pold)
{
  if (new < 0)
    (* pold) = output_cooked_p;
  else
    output_cooked_p = (new ? 1 : 0);
}

static void
write_char (char c, int cooked_p)
{
  write_output ((&c), 1, cooked_p);
}

void
OS2_console_write (const char * data, size_t size)
{
  write_output (data, size, 2);
}

static void
write_output (const char * data, size_t size, int cooked_p)
{
  const char * scan = data;
  const char * end = (scan + size);
  char output_translation [256];
  char * out = output_translation;
  char * out_limit = (out + ((sizeof (output_translation)) - 4));
  char c;
  if (cooked_p == 0)
    write_output_1 (scan, end);
  else
    while (1)
      {
	if ((scan == end) || (out >= out_limit))
	  {
	    write_output_1 (output_translation, out);
	    if (scan == end)
	      break;
	    out = output_translation;
	  }
	c = (*scan++);
	if ((cooked_p == 2) && (c == '\n'))
	  {
	    (*out++) = '\r';
	    (*out++) = '\n';
	  }
	else if ((isprint (c))
		 || (c == '\f')
		 || (c == '\a')
		 || (c == '\r')
		 || (c == '\n'))
	  (*out++) = c;
	else if (c < 0x20)
	  {
	    (*out++) = '^';
	    (*out++) = ('@' + c);
	  }
	else
	  {
	    (*out++) = '\\';
	    (*out++) = ('0' + ((c >> 6) & 3));
	    (*out++) = ('0' + ((c >> 3) & 7));
	    (*out++) = ('0' + (c & 7));
	  }
      }
}

static void
write_output_1 (const char * scan, const char * end)
{
#ifdef USE_PMCON

  OS2_pm_console_write (scan, (end - scan));

#else /* not USE_PMCON */
#ifdef USE_PMIO

  put_raw ((end - scan), scan);

#else /* not USE_PMIO */
#ifdef USE_VIO

  STD_API_CALL (vio_wrt_tty, (((PCH) scan), (end - scan), 0));

#else /* not USE_VIO */

  while (1)
    {
      ULONG n;
      APIRET rc = (dos_write (1, ((void *) scan), (end - scan), (& n)));
      if (rc != NO_ERROR)
	break;
      scan += n;
      if (scan == end)
	break;
    }

#endif /* not USE_VIO */
#endif /* not USE_PMIO */
#endif /* not USE_PMCON */
}

static unsigned int
char_output_length (char c)
{
  return ((isprint (c)) ? 1 : (c < 0x20) ? 2 : 4);
}
