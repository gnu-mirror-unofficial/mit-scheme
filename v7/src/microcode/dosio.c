/* -*-C-*-

$Id: dosio.c,v 1.9 1999/01/02 06:11:34 cph Exp $

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
#include "dosio.h"
#include "osterm.h"

#ifndef fileno
#define fileno(fp)	((fp)->_file)
#endif

size_t OS_channel_table_size;
struct channel * channel_table;

static void
DEFUN_VOID (DOS_channel_close_all)
{
  Tchannel channel;
  for (channel = 0; (channel < OS_channel_table_size); channel += 1)
    if (CHANNEL_OPEN_P (channel))
      OS_channel_close_noerror (channel);
  return;
}

void
DEFUN_VOID (DOS_initialize_channels)
{
  OS_channel_table_size = (DOS_SC_OPEN_MAX ());
  channel_table =
    (DOS_malloc (OS_channel_table_size * (sizeof (struct channel))));
  if (channel_table == 0)
    {
      fprintf (stderr, "\nUnable to allocate channel table.\n");
      fflush (stderr);
      termination_init_error ();
    }
  {
    Tchannel channel;
    for (channel = 0; (channel < OS_channel_table_size); channel += 1)
      MARK_CHANNEL_CLOSED (channel);
  }
  add_reload_cleanup (DOS_channel_close_all);
}

void
DEFUN_VOID (DOS_reset_channels)
{
  DOS_free (channel_table);
  channel_table = 0;
  OS_channel_table_size = 0;
  return;
}

Tchannel
DEFUN_VOID (channel_allocate)
{
  Tchannel channel = 0;
  while (1)
  {
    if (channel == OS_channel_table_size)
      error_out_of_channels ();
    if (CHANNEL_CLOSED_P (channel))
      return (channel);
    channel += 1;
  }
}

int
DEFUN (OS_channel_open_p, (channel), Tchannel channel)
{
  return (CHANNEL_OPEN_P (channel));
}

void
DEFUN (OS_channel_close, (channel), Tchannel channel)
{
  if (! (CHANNEL_INTERNAL (channel)))
  {
    STD_VOID_SYSTEM_CALL
      (syscall_close, (DOS_close (CHANNEL_DESCRIPTOR (channel))));
    MARK_CHANNEL_CLOSED (channel);
  }
  return;
}

void
DEFUN (OS_channel_close_noerror, (channel), Tchannel channel)
{
  if (! (CHANNEL_INTERNAL (channel)))
  {
    DOS_close (CHANNEL_DESCRIPTOR (channel));
    MARK_CHANNEL_CLOSED (channel);
  }
  return;
}

static void
DEFUN (channel_close_on_abort_1, (cp), PTR cp)
{
  OS_channel_close (* ((Tchannel *) cp));
  return;
}

void
DEFUN (OS_channel_close_on_abort, (channel), Tchannel channel)
{
  Tchannel * cp = (dstack_alloc (sizeof (Tchannel)));
  (*cp) = (channel);
  transaction_record_action (tat_abort, channel_close_on_abort_1, cp);
  return;
}

enum channel_type
DEFUN (OS_channel_type, (channel), Tchannel channel)
{
  return (CHANNEL_TYPE (channel));
}

void
DEFUN (OS_terminal_flush_input, (channel), Tchannel channel)
{ extern void EXFUN (flush_conio_buffers, (void));

  if ((CHANNEL_DESCRIPTOR (channel)) == (fileno (stdin)))
    flush_conio_buffers();
  return;
}

void
DEFUN (OS_terminal_flush_output, (channel), Tchannel channel)
{
  return;
}

void
DEFUN (OS_terminal_drain_output, (channel), Tchannel channel)
{
  return;
}

extern int EXFUN (dos_read, (int, PTR, size_t, int, int, int));

int
DEFUN (dos_read, (fd, buffer, nbytes, buffered_p, blocking_p, intrpt_p),
       int fd AND PTR buffer AND size_t nbytes
       AND int buffered_p AND int blocking_p AND int intrpt_p)
{
  if (nbytes == 0)
    return (0);
  else if (fd == (fileno (stdin)))
    return (console_read (buffer, nbytes, buffered_p, blocking_p, intrpt_p));
  else
    return (DOS_read (fd, buffer, nbytes));
}

int
DEFUN (dos_channel_read, (channel, buffer, nbytes),
       Tchannel channel AND PTR buffer AND size_t nbytes)
{
  if (nbytes == 0)
    return 0;
  else if ((CHANNEL_DESCRIPTOR (channel)) == (fileno (stdin)))
    return (console_read (buffer, nbytes, 
			  (CHANNEL_BUFFERED (channel)),
			  (CHANNEL_BLOCKING_P (channel)),
			  1));
  else
    return (DOS_read ((CHANNEL_DESCRIPTOR (channel)), buffer, nbytes));
}

long
DEFUN (OS_channel_read, (channel, buffer, nbytes),
       Tchannel channel AND PTR buffer AND size_t nbytes)
{
  while (1)
  {
    long scr = (dos_channel_read (channel, buffer, nbytes));
    if (scr < 0)
    {
      if (errno == ERRNO_NONBLOCK)
	return -1;
      DOS_prim_check_errno (syscall_read);
      continue;
    }
    else if (scr > nbytes)
      error_external_return ();
    else
      return (scr);
  }
}

static int
DEFUN (dos_write, (fd, buffer, nbytes),
       int fd AND CONST unsigned char * buffer AND size_t nbytes)
{
  return ((fd == (fileno (stdout)))
	  ? (dos_console_write (buffer, nbytes))
	  : (DOS_write (fd, buffer, nbytes)));
}

#define Syscall_Write(fd, buffer, size, so_far)		\
do							\
{ size_t _size = (size);				\
  int _written;						\
  _written = dos_write ((fd), (buffer), (_size));	\
  if (_size != _written)				\
    return ((_written < 0) ? -1 : (so_far) + _written); \
} while (0)

long
DEFUN (text_write, (fd, buffer, nbytes),
       int fd AND CONST unsigned char * buffer AND size_t nbytes)
{ /* Map LF to CR/LF */
  static CONST unsigned char crlf[] = {CARRIAGE_RETURN, LINEFEED};
  CONST unsigned char *start;
  size_t i;

  for (i = 0, start = buffer; i < nbytes; start = &buffer[i])
  { size_t len;

    while ((i < nbytes) && (buffer[i] != LINEFEED)) i++;
    len = (&buffer[i] - start);

    Syscall_Write (fd, start, len, (i - len));

    if ((i < nbytes) && (buffer[i] == LINEFEED))
    { /* We are sitting on a linefeed. Write out CRLF */
      /* This backs out incorrectly if only CR is written out */
      Syscall_Write (fd, crlf, (sizeof (crlf)), i);
      i = i + 1; /* Skip over special character */
    }
  }
  return nbytes;
}

#undef Syscall_Write

long
DEFUN (OS_channel_write, (channel, buffer, nbytes),
       Tchannel channel AND CONST PTR buffer AND size_t nbytes)
{
  if (nbytes == 0)
    return (0);

  while (1)
  {
    int fd, scr;

    fd = CHANNEL_DESCRIPTOR(channel);
    scr = ((CHANNEL_COOKED (channel))
	   ? (text_write (fd, buffer, nbytes))
	   : (dos_write (fd, buffer, nbytes)));
	      
    if (scr < 0)
    {
      DOS_prim_check_errno (syscall_write);
      continue;
    }

    if (scr > nbytes)
      error_external_return ();
    return scr;
  }
}

size_t
DEFUN (OS_channel_read_load_file, (channel, buffer, nbytes),
       Tchannel channel AND PTR buffer AND size_t nbytes)
{
  int scr;
  scr = (DOS_read ((CHANNEL_DESCRIPTOR (channel)), buffer, nbytes));
  return ((scr < 0) ? 0 : scr);
}

size_t
DEFUN (OS_channel_write_dump_file, (channel, buffer, nbytes),
       Tchannel channel AND CONST PTR buffer AND size_t nbytes)
{
  int scr = (DOS_write ((CHANNEL_DESCRIPTOR (channel)), buffer, nbytes));
  return ((scr < 0) ? 0 : scr);
}

void
DEFUN (OS_channel_write_string, (channel, string),
       Tchannel channel AND
       CONST char * string)
{
  unsigned long length = (strlen (string));
  if ((OS_channel_write (channel, string, length)) != length)
    error_external_return ();
}

void
DEFUN (OS_make_pipe, (readerp, writerp),
       Tchannel * readerp AND
       Tchannel * writerp)
{
  return;
}

int
DEFUN (OS_channel_nonblocking_p, (channel), Tchannel channel)
{
  return (CHANNEL_NONBLOCKING (channel));
}

void
DEFUN (OS_channel_nonblocking, (channel), Tchannel channel)
{
  (CHANNEL_NONBLOCKING (channel)) = 1;
  return;
}

void
DEFUN (OS_channel_blocking, (channel), Tchannel channel)
{
  (CHANNEL_NONBLOCKING (channel)) = 0;
}

int
DEFUN (OS_terminal_buffered_p, (channel), Tchannel channel)
{
  return (CHANNEL_BUFFERED(channel));
}

void
DEFUN (OS_terminal_buffered, (channel), Tchannel channel)
{
  CHANNEL_BUFFERED(channel) = 1;
}

void
DEFUN (OS_terminal_nonbuffered, (channel), Tchannel channel)
{
  CHANNEL_BUFFERED(channel) = 0;
}

int
DEFUN (OS_terminal_cooked_output_p, (channel), Tchannel channel)
{
  return (CHANNEL_COOKED(channel));
}

void
DEFUN (OS_terminal_cooked_output, (channel), Tchannel channel)
{
  CHANNEL_COOKED(channel) = 1;
}

void
DEFUN (OS_terminal_raw_output, (channel), Tchannel channel)
{
  CHANNEL_COOKED(channel) = 0;
}

unsigned int
DEFUN (arg_baud_index, (argument), unsigned int argument)
{
  return (arg_index_integer (argument, 1));
}

unsigned int
DEFUN (OS_terminal_get_ispeed, (channel), Tchannel channel)
{
  return (0);
}

unsigned int
DEFUN (OS_terminal_get_ospeed, (channel), Tchannel channel)
{
  return (0);
}

void
DEFUN (OS_terminal_set_ispeed, (channel, baud),
       Tchannel channel AND
       unsigned int baud)
{
  error_unimplemented_primitive ();
}

void
DEFUN (OS_terminal_set_ospeed, (channel, baud),
       Tchannel channel AND
       unsigned int baud)
{
  error_unimplemented_primitive ();
}

unsigned int
DEFUN (OS_baud_index_to_rate, (index), unsigned int index)
{
  return (9600);
}

int
DEFUN (OS_baud_rate_to_index, (rate), unsigned int rate)
{
  return ((rate == 9600) ? 0 : -1);
}

unsigned int
DEFUN_VOID (OS_terminal_state_size)
{
  return (3);
}

void
DEFUN (OS_terminal_get_state, (channel, state_ptr),
       Tchannel channel AND PTR state_ptr)
{
  unsigned char *statep = (unsigned char *) state_ptr;

  *statep++ = CHANNEL_NONBLOCKING(channel);
  *statep++ = CHANNEL_BUFFERED(channel);
  *statep   = CHANNEL_COOKED(channel);
  
  return;
}

void
DEFUN (OS_terminal_set_state, (channel, state_ptr),
       Tchannel channel AND PTR state_ptr)
{
  unsigned char *statep = (unsigned char *) state_ptr;

  CHANNEL_NONBLOCKING(channel) = *statep++;
  CHANNEL_BUFFERED(channel)    = *statep++;
  CHANNEL_COOKED(channel)      = *statep;
  
  return;
}

#ifndef FALSE
#  define FALSE 0
#endif

int
DEFUN_VOID (OS_job_control_p)
{
  return (FALSE);
}

int
DEFUN_VOID (OS_have_ptys_p)
{
  return (FALSE);
}

/* No SELECT in DOS */
CONST int OS_have_select_p = 0;
